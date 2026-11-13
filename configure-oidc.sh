#!/usr/bin/env bash
# Applies (or re-applies) the Keycloak/OIDC configuration of the IRIS instances: roles, OAuth 2.0
# server definition, resource server and OAuth2 on the web applications - see iris/src/adm/oidc.cls.
#
# Needed for an EXISTING container: the same code runs in iris/iris.script at image build time, but the
# durable %SYS volumes keep the configuration of their first start, so a rebuild alone does not reach them.
# Idempotent: safe to run as many times as you like.
#
# Usage: ./configure-oidc.sh [--target local|aws] [--instance dev|prod|both] [--issuer URL] [--backchannel URL] [--dry-run]
#   --issuer / --backchannel: realm URL put in the tokens / realm URL IRIS itself calls (default: the values of adm.oidc);
#   they are remembered by the instance. AWS: --issuer https://<host>/auth/realms/iris --backchannel http://keycloak:8080/auth/realms/iris
#   local: prompts for an IRIS user/password (or set IRIS_LOGIN_USER and IRIS_LOGIN_PASSWORD)
#   aws:   runs over ssh (cloudenv); the console of the AWS containers needed no login so far
set -euo pipefail
cd "$(dirname "$0")"

TARGET=local; INSTANCE=dev; DRYRUN=0; ISSUER=""; BACKCHANNEL=""
while [ $# -gt 0 ]; do
    case "$1" in
        --target)   TARGET="${2:-}"; shift 2 ;;
        --instance) INSTANCE="${2:-}"; shift 2 ;;
        --issuer)   ISSUER="${2:-}"; shift 2 ;;
        --backchannel) BACKCHANNEL="${2:-}"; shift 2 ;;
        --dry-run)  DRYRUN=1; shift ;;
        -h|--help)  sed -n '2,/^set /p' "$0" | sed 's/^# \{0,1\}//' | head -n -1; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done
case "$TARGET" in local|aws) ;; *) echo "ERROR: --target local|aws" >&2; exit 1 ;; esac
case "$INSTANCE" in dev) S=(dev) ;; prod) S=(prod) ;; both) S=(dev prod) ;; *) echo "ERROR: --instance dev|prod|both" >&2; exit 1 ;; esac
# shellcheck disable=SC1091
source .env

# ObjectScript sent base64-encoded (no quoting issue through ssh). /code is the bind mount of iris/src.
OS_B64="$(printf '%s\n' \
    'zn "COMMON"' \
    'set sc=$SYSTEM.OBJ.Load("/code/adm/oidc.cls","ck")' \
    "set sc=##class(adm.oidc).Configure(,1,\"$ISSUER\",\"$BACKCHANNEL\")" \
    'halt' | base64 | tr -d '\n')"

LOGIN=""
if [ "$TARGET" = local ]; then
    : "${IRIS_LOGIN_USER:=}"; 
    if [ -z "$IRIS_LOGIN_USER" ] && [ "$DRYRUN" = 0 ]; then read -r -p "IRIS user: " IRIS_LOGIN_USER; fi
    if [ -z "${IRIS_LOGIN_PASSWORD:-}" ] && [ "$DRYRUN" = 0 ]; then read -r -s -p "IRIS password: " IRIS_LOGIN_PASSWORD; echo; fi
else
    # shellcheck disable=SC1091
    source cloudenv
fi

for s in "${S[@]}"; do
    C="${IRIS_INSTANCE_NAME}-$s"
    echo "=== $TARGET / $C"
    if [ "$DRYRUN" = 1 ]; then echo "  [dry-run] iris session IRIS -U %SYS in $C with: zn COMMON; load /code/adm/oidc.cls; adm.oidc.Configure()"; continue; fi
    if [ "$TARGET" = local ]; then
        { printf '%s\n%s\n' "$IRIS_LOGIN_USER" "$IRIS_LOGIN_PASSWORD"; echo "$OS_B64" | base64 -d; } \
            | docker exec -i "$C" iris session IRIS -U %SYS 2>&1
    else
        echo "$OS_B64" | base64 -d | ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" "docker exec -i $C iris session IRIS -U %SYS" 2>&1
    fi | grep -vE '^$|Node:|Username:|Password:|^[A-Za-z0-9._-]+:[A-Z%]+>$' | sed -E 's/^[A-Za-z0-9._-]+:[A-Z%]+>//' | grep -v '^$'
done
