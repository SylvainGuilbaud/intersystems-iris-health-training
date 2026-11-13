#!/usr/bin/env bash
# Build the Angular app for cloud/AWS deployment.
#
# Output: iris/angular/dist/hl7-client/browser/
# Served at: http://<host>/app/   (baseHref=/app/)
# Mounted into the nginx container at /usr/share/nginx/html/app (see docker-compose.yml).
#
# Usage:
#   ./build-cloud-angular.sh          # build then push to AWS
#   ./build-cloud-angular.sh --local  # build only (no push)

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ANGULAR_DIR="$REPO_DIR/iris/angular"
DIST="$ANGULAR_DIR/dist/hl7-client/browser"

echo "==> Installing dependencies..."
cd "$ANGULAR_DIR"
npm install

echo "==> Building Angular app (configuration: cloud)..."
npx ng build --configuration cloud

DIST="$ANGULAR_DIR/dist/hl7-client/browser"
echo "==> Build complete: $DIST"
ls -lh "$DIST"

if [ "${1}" = "--local" ]; then
    echo "==> --local flag set, skipping push to AWS."
    exit 0
fi

# ── Push to AWS ──────────────────────────────────────────────────────────────
cd "$REPO_DIR"
source cloudenv

REMOTE_BASE="intersystems-iris-health-training"
REMOTE_DIST="$REMOTE_BASE/iris/angular/dist/hl7-client/browser"

echo "==> Creating remote directories on $PUBLIC_DNS..."
ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
    "mkdir -p $REMOTE_DIST"

echo "==> Copying Angular dist to $PUBLIC_DNS..."
ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
    "rm -rf $REMOTE_DIST/*"
scp -r -i "$ACCESS_KEY_FILENAME" \
    "$DIST"/* \
    "$CLOUD_USERNAME@$PUBLIC_DNS:$REMOTE_DIST/"

# If Keycloak/HTTPS were deployed with ./deploy-keycloak-aws.sh, the host runs docker-compose.yml + docker-compose.aws-keycloak.yml
# and a nginx.conf/tls.aws.conf of its own: the local docker-compose.yml and nginx.conf must NOT overwrite them
# (they know neither port 443 nor the ACME location, and mount files that do not exist on the host).
KC_ON_HOST=$(ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
    "[ -f $REMOTE_BASE/docker-compose.aws-keycloak.yml ] && echo yes || echo no")

echo "==> Copying updated CSP.conf (and docker-compose.yml, nginx config unless the Keycloak/HTTPS deployment is present)..."
scp -i "$ACCESS_KEY_FILENAME" \
    "$REPO_DIR/webgateway/CSP.conf" \
    "$CLOUD_USERNAME@$PUBLIC_DNS:$REMOTE_BASE/webgateway/CSP.conf"
if [ "$KC_ON_HOST" = yes ]; then
    echo "    Keycloak/HTTPS deployment detected on the host: docker-compose.yml and nginx.conf are NOT overwritten."
else
    scp -i "$ACCESS_KEY_FILENAME" \
        "$REPO_DIR/docker-compose.yml" \
        "$CLOUD_USERNAME@$PUBLIC_DNS:$REMOTE_BASE/docker-compose.yml"
    ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
        "mkdir -p $REMOTE_BASE/nginx"
    scp -i "$ACCESS_KEY_FILENAME" \
        "$REPO_DIR/nginx/nginx.conf" \
        "$CLOUD_USERNAME@$PUBLIC_DNS:$REMOTE_BASE/nginx/nginx.conf"
fi

echo "==> Starting nginx container on $PUBLIC_DNS..."
if [ "$KC_ON_HOST" = yes ]; then
    ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
        "cd $REMOTE_BASE && IRIS_INSTANCE_NAME=\$(grep '^IRIS_INSTANCE_NAME=' .env | cut -d= -f2) && sudo env PUBLIC_HOST=$PUBLIC_DNS NGINX_TLS_CONF=tls.aws.conf docker compose -p \"\$IRIS_INSTANCE_NAME\" -f docker-compose.yml -f docker-compose.aws-keycloak.yml up -d --no-deps nginx 2>&1"
else
    ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
        "cd $REMOTE_BASE && IRIS_INSTANCE_NAME=\$(grep '^IRIS_INSTANCE_NAME=' .env | cut -d= -f2) && sudo docker compose -p \"\$IRIS_INSTANCE_NAME\" up -d --no-deps nginx 2>&1"
fi

echo "==> Refreshing webgateway if present..."
ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
        "cd $REMOTE_BASE && \
         IRIS_INSTANCE_NAME=\$(grep '^IRIS_INSTANCE_NAME=' .env | cut -d= -f2) && \
         WG_CID=\$(sudo docker compose -p \"\$IRIS_INSTANCE_NAME\" ps -q webgateway) && \
         if [ -n \"\$WG_CID\" ]; then \
             echo 'Webgateway container found, reloading Apache...' && \
             sudo docker exec \"\$WG_CID\" apache2ctl graceful 2>&1; \
         else \
             echo 'Webgateway container not found in compose project, skipping reload.'; \
         fi"

echo "==> Done. App accessible at http://$PUBLIC_DNS/app/"
