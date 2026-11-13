#!/usr/bin/env bash
# Generates / completes keycloak/secrets.env (git-ignored) with random secrets for the local Keycloak
# and oauth2-proxy. Existing values are never overwritten; only missing keys are appended, so it is safe
# to re-run after an update of this script.
set -euo pipefail
cd "$(dirname "$0")"

OUT=secrets.env
rnd() { openssl rand -base64 48 | tr -d '/+=\n' | cut -c1-"${1:-32}"; }
umask 077
[ -f "$OUT" ] || printf '# Generated %s. Never commit this file.\n' "$(date +%Y-%m-%d)" > "$OUT"

get() { grep -m1 "^$1=" "$OUT" | cut -d= -f2- || true; }
add() { # add KEY VALUE  (only if KEY is missing)
    if [ -z "$(get "$1")" ]; then printf '%s=%s\n' "$1" "$2" >> "$OUT"; echo "added $1"; fi
}

add KC_BOOTSTRAP_ADMIN_USERNAME admin
add KC_BOOTSTRAP_ADMIN_PASSWORD "$(rnd 24)"
add IRIS_PORTAL_CLIENT_SECRET "$(rnd 40)"
add IRIS_SERVICE_CLIENT_SECRET "$(rnd 40)"
# Initial password of the demo users (Keycloak forces a change at first login)
add IRIS_DEMO_USER_PASSWORD "$(rnd 16)"
# oauth2-proxy reads OAUTH2_PROXY_* variables: same client secret as iris-portal, plus its cookie key (32 bytes)
add OAUTH2_PROXY_COOKIE_SECRET "$(rnd 32)"
if [ -z "$(get OAUTH2_PROXY_CLIENT_SECRET)" ]; then printf 'OAUTH2_PROXY_CLIENT_SECRET=%s\n' "$(get IRIS_PORTAL_CLIENT_SECRET)" >> "$OUT"; echo "added OAUTH2_PROXY_CLIENT_SECRET"; fi
chmod 600 "$OUT"
echo "$PWD/$OUT is complete (mode 600). Read the admin and demo passwords in that file."
