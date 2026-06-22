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

echo "==> Copying updated docker-compose.yml, CSP.conf and nginx config..."
scp -i "$ACCESS_KEY_FILENAME" \
    "$REPO_DIR/webgateway/CSP.conf" \
    "$CLOUD_USERNAME@$PUBLIC_DNS:$REMOTE_BASE/webgateway/CSP.conf"
scp -i "$ACCESS_KEY_FILENAME" \
    "$REPO_DIR/docker-compose.yml" \
    "$CLOUD_USERNAME@$PUBLIC_DNS:$REMOTE_BASE/docker-compose.yml"
ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
    "mkdir -p $REMOTE_BASE/nginx"
scp -i "$ACCESS_KEY_FILENAME" \
    "$REPO_DIR/nginx/nginx.conf" \
    "$CLOUD_USERNAME@$PUBLIC_DNS:$REMOTE_BASE/nginx/nginx.conf"

echo "==> Starting nginx container on $PUBLIC_DNS..."
ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
    "cd $REMOTE_BASE && IRIS_INSTANCE_NAME=\$(grep '^IRIS_INSTANCE_NAME=' .env | cut -d= -f2) && sudo docker compose -p \"\$IRIS_INSTANCE_NAME\" up -d --no-deps nginx 2>&1"

echo "==> Restoring webgateway (remove old Angular mount)..."
ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" \
    "sudo docker exec iris-health-training-webgateway-1 apache2ctl graceful 2>&1"

echo "==> Done. App accessible at http://$PUBLIC_DNS/app/"
