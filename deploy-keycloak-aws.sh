#!/usr/bin/env bash
# Deploys Keycloak (production mode, dedicated Postgres), oauth2-proxy and HTTPS on the AWS host, and configures IRIS.
# See docs/Keycloak-IRIS-Security.md. Idempotent: every stage can be run again.
#
# Architecture: nginx (port 443, the only port open from the Internet besides 80) serves
#   https://<host>/auth      Keycloak (admin console NOT public: SSH tunnel to 127.0.0.1:8180)
#   https://<host>/oauth2    oauth2-proxy (browser login for the IRIS portal)
# The docker-compose.yml already on the host is NOT replaced: docker-compose.aws-keycloak.yml is added to it.
#
# Usage: ./deploy-keycloak-aws.sh [--dry-run] [--cert letsencrypt|selfsigned] [stage ...]
# Stages (default: all, in this order):
#   prepare  copy files, patch nginx.conf (backup), generate secrets ON THE HOST, validate the compose files
#   cert     recreate nginx for the ACME challenge, get a Let's Encrypt certificate (fallback: self-signed)
#   up       start Keycloak + its database, enable TLS on nginx, start oauth2-proxy
#   iris     configure IRIS (adm.oidc) on aws-dev with the public issuer and the internal back-channel URL
#   verify   checks from this machine (HTTPS, Keycloak, token, API, portal redirect)
#
# Secrets never leave the host: keycloak/secrets.env is generated there. Let's Encrypt is registered without e-mail
# (--register-unsafely-without-email) and its terms of service are accepted on your behalf; renewal is NOT automated.
set -euo pipefail
cd "$(dirname "$0")"

DRYRUN=0; CERT=letsencrypt; STAGES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRYRUN=1; shift ;;
        --cert)    CERT="${2:-}"; shift 2 ;;
        -h|--help) sed -n '2,/^set /p' "$0" | sed 's/^# \{0,1\}//' | head -n -1; exit 0 ;;
        prepare|cert|up|iris|verify) STAGES+=("$1"); shift ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done
case "$CERT" in letsencrypt|selfsigned) ;; *) echo "ERROR: --cert letsencrypt|selfsigned" >&2; exit 1 ;; esac
[ ${#STAGES[@]} -gt 0 ] || STAGES=(prepare cert up iris verify)

# shellcheck disable=SC1091
source cloudenv
HOST="$PUBLIC_DNS"
REMOTE="intersystems-iris-health-training"
PROJECT="iris-health-training"
ISSUER="https://$HOST/auth/realms/iris"
BACK="http://keycloak:8080/auth/realms/iris"
SSH=(ssh -i "$ACCESS_KEY_FILENAME" -o ConnectTimeout=15 "$CLOUD_USERNAME@$HOST")

# on_host <label>: runs the bash script read on stdin on the AWS host (from the project directory)
on_host() {
    local label="$1" script; script="$(cat)"
    echo "  -> $label"
    if [ "$DRYRUN" = 1 ]; then printf '%s\n' "$script" | sed 's/^/       | /'; return 0; fi
    "${SSH[@]}" "cd $REMOTE && bash -s" <<<"$script"
}
put() { # <local> <remote path relative to the project>
    echo "  -> copy $1 -> $2"
    [ "$DRYRUN" = 1 ] || scp -q -i "$ACCESS_KEY_FILENAME" "$1" "$CLOUD_USERNAME@$HOST:$REMOTE/$2"
}
# docker compose on the host: existing file + our override, project name of the running containers
DC="PUBLIC_HOST=$HOST docker compose -p $PROJECT -f docker-compose.yml -f docker-compose.aws-keycloak.yml"

stage_prepare() {
    echo "== prepare"
    on_host "directories" <<'EOF'
set -e
mkdir -p keycloak nginx/letsencrypt nginx/certbot-www keycloak/db-data iris/src/adm
EOF
    put docker-compose.aws-keycloak.yml docker-compose.aws-keycloak.yml
    put nginx/tls.aws.conf              nginx/tls.aws.conf
    put nginx/tls.disabled.conf         nginx/tls.disabled.conf
    put keycloak/realm-iris.json        keycloak/realm-iris.json
    put keycloak/init-secrets.sh        keycloak/init-secrets.sh
    put iris/src/adm/oidc.cls           iris/src/adm/oidc.cls
    on_host "nginx.conf: add the ACME challenge location (backup first), generate secrets, validate compose" <<EOF
set -e
chmod +x keycloak/init-secrets.sh
if ! grep -q 'acme-challenge' nginx/nginx.conf; then
    cp -p nginx/nginx.conf nginx/nginx.conf.bak-\$(date +%Y%m%d-%H%M%S)
    python3 - <<'PY'
p='nginx/nginx.conf'; s=open(p).read()
blk="    # Let's Encrypt HTTP-01 challenge (deploy-keycloak-aws.sh)\n    location ^~ /.well-known/acme-challenge/ {\n        root /var/www/certbot;\n    }\n\n"
assert s.count('    listen 80;\n')==1
s=s.replace('    listen 80;\n','    listen 80;\n\n'+blk,1); open(p,'w').write(s); print('acme location added')
PY
else echo "acme location already present"; fi
./keycloak/init-secrets.sh >/dev/null && echo "secrets ready (keycloak/secrets.env, mode 600, not printed)"
$DC config --quiet && echo "compose files valid"
EOF
}

stage_cert() {
    echo "== cert ($CERT)"
    on_host "nginx: recreate with the ACME webroot (no TLS server yet)" <<EOF
set -e
$DC up -d --no-deps nginx
sleep 3
curl -s -o /dev/null -w '  port 80 still answers: HTTP %{http_code}\n' http://localhost/app/
EOF
    on_host "certificate" <<EOF
set -e
LIVE=nginx/letsencrypt/live
mkdir -p \$LIVE
got=0
if [ "$CERT" = letsencrypt ]; then
    if docker run --rm -v "\$PWD/nginx/letsencrypt:/etc/letsencrypt" -v "\$PWD/nginx/certbot-www:/var/www/certbot" \
        certbot/certbot certonly --webroot -w /var/www/certbot -d $HOST \
        --agree-tos --register-unsafely-without-email --non-interactive --keep-until-expiring 2>&1 | tail -6; then
        [ -f "\$LIVE/$HOST/fullchain.pem" ] && got=1
    fi
    [ "\$got" = 1 ] && echo "  Let's Encrypt certificate obtained" || echo "  WARNING: Let's Encrypt refused or failed: falling back to a self-signed certificate"
fi
if [ "\$got" = 0 ]; then
    mkdir -p "\$LIVE/$HOST"
    docker run --rm -v "\$PWD/nginx/letsencrypt:/etc/letsencrypt" alpine/openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
        -subj "/CN=$HOST" -addext "subjectAltName=DNS:$HOST" \
        -keyout /etc/letsencrypt/live/$HOST/privkey.pem -out /etc/letsencrypt/live/$HOST/fullchain.pem 2>/dev/null
    echo "  SELF-SIGNED certificate created (browsers will warn)"
fi
ln -sfn "$HOST" "\$LIVE/current"
echo "  live/current -> \$(readlink \$LIVE/current)"
EOF
}

stage_up() {
    echo "== up"
    on_host "Keycloak database and Keycloak (first start builds the server: allow ~1-2 min)" <<EOF
set -e
$DC up -d --no-deps keycloak-db keycloak
for i in \$(seq 1 60); do
    c=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8180/auth/realms/iris/.well-known/openid-configuration || true)
    [ "\$c" = 200 ] && { echo "  Keycloak answers (realm iris) after ~\$((i*5))s"; exit 0; }
    sleep 5
done
echo "  WARNING: Keycloak did not answer in 5 minutes: docker logs ${PROJECT}-keycloak"; exit 1
EOF
    on_host "oauth2-proxy, then nginx with TLS" <<EOF
set -e
$DC up -d --no-deps oauth2-proxy
NGINX_TLS_CONF=tls.aws.conf $DC up -d --no-deps nginx
sleep 3
docker exec ${PROJECT}-nginx nginx -t 2>&1 | tail -1
docker ps --format '  {{.Names}}  {{.Status}}' | grep -E 'nginx|keycloak|oauth2'
EOF
}

stage_iris() {
    echo "== iris"
    echo "  -> configure-oidc.sh --target aws with the public issuer and the internal back-channel"
    if [ "$DRYRUN" = 1 ]; then ./configure-oidc.sh --target aws --instance dev --issuer "$ISSUER" --backchannel "$BACK" --dry-run
    else ./configure-oidc.sh --target aws --instance dev --issuer "$ISSUER" --backchannel "$BACK"; fi
}

stage_verify() {
    echo "== verify (from this machine)"
    [ "$DRYRUN" = 1 ] && { echo "  [dry-run] checks skipped"; return 0; }
    local k=""; [ "$CERT" = selfsigned ] && k="-k"
    # a self-signed certificate is detected rather than assumed
    curl -sS -m 10 -o /dev/null "https://$HOST/app/" 2>/dev/null || k="-k"
    [ "$k" = "-k" ] && echo "  note: the certificate is not trusted by this machine (self-signed): using -k for the checks"
    chk() { printf '  %-58s ' "$1"; shift; "$@" | head -c 130 | tr '\n\r' '  '; echo; }
    chk "OIDC discovery (issuer must be the public https URL)" bash -c "curl -s $k -m 15 https://$HOST/auth/realms/iris/.well-known/openid-configuration | python3 -c \"import sys,json;d=json.load(sys.stdin);print('issuer =',d['issuer'])\""
    chk "admin console is NOT public (expect 404)" curl -s $k -m 10 -o /dev/null -w "HTTP %{http_code}" "https://$HOST/auth/admin/master/console/"
    chk "master realm is NOT public (expect 404)" curl -s $k -m 10 -o /dev/null -w "HTTP %{http_code}" "https://$HOST/auth/realms/master/.well-known/openid-configuration"
    chk "portal without session -> 302 to Keycloak" bash -c "curl -s $k -m 10 -o /dev/null -w 'HTTP %{http_code} -> ' -D - https://$HOST/iris-health-training-dev/csp/sys/UtilHome.csp | grep -iE '^(HTTP|location)' | head -2 | cut -c1-110 | tr '\n\r' '  '"
}

for s in "${STAGES[@]}"; do "stage_$s"; done
echo "Done."
