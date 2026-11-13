#!/usr/bin/env bash
# Tests the Keycloak-protected IRIS HTTP API (docs/Keycloak-IRIS-Security.md, section 4.2).
# Sends the same HL7 LAB-27 query three times: with a valid token, with a tampered token, without token.
#
# Usage: ./keycloak/test-api.sh [https://localhost] [namespace]      (defaults: https://localhost, dglab)
# Needs keycloak/secrets.env and the keycloak container; works from bash or zsh (run it, do not paste comments).
set -euo pipefail
cd "$(dirname "$0")/.."

BASE="${1:-https://localhost}"
NS="${2:-dglab}"
URL="$BASE/iris-health-training-dev/csp/healthshare/$NS/EnsLib.HL7.Service.HTTPService.cls?CfgItem=LAW%20LAB-27%20Query%20for%20AWOS%20-%20HTTP"

# shellcheck disable=SC1091
set -a; . keycloak/secrets.env; set +a
TOKEN="$(curl -s --resolve keycloak:8180:127.0.0.1 -X POST http://keycloak:8180/realms/iris/protocol/openid-connect/token \
  -d grant_type=client_credentials -d client_id=iris-service \
  --data-urlencode "client_secret=$IRIS_SERVICE_CLIENT_SECRET" \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")"
unset IRIS_SERVICE_CLIENT_SECRET IRIS_PORTAL_CLIENT_SECRET IRIS_DEMO_USER_PASSWORD KC_BOOTSTRAP_ADMIN_PASSWORD OAUTH2_PROXY_CLIENT_SECRET OAUTH2_PROXY_COOKIE_SECRET
echo "jeton obtenu (${#TOKEN} caractères)"

# HL7 LAB-27 demo message (segments separated by CR)
MSG="$(printf 'MSH|^~\\&|ANALYZER|LAB|LIS|LAB|20261113190000||QBP^Q11^QBP_Q11|QBP1|P|2.5.1|||NE|AL||UNICODE UTF-8|||LAB-27^IHE\rQPD|WOS^Work Order Step^IHE_LABTF|Q1|CT99\rRCP|I||R')"

show() { # label, expected, then curl args
    local label="$1" expected="$2"; shift 2
    local out
    # Content-Type text/plain is required: with the default form encoding IRIS swallows the body as form fields.
    out="$(curl -sk -m 30 -H 'Content-Type: text/plain' --data-binary "$MSG" "$@" "$URL" | tr '\r' '\n' | sed 's/<[^>]*>//g' | grep -v '^[[:space:]]*$' | head -2 | cut -c1-110 || true)"
    if printf '%s' "$out" | grep -q "$expected"; then ok="OK    "; else ok="ECHEC "; fi
    printf '%s%-18s -> %s\n' "$ok" "$label" "$(printf '%s' "$out" | head -1)"
}

show "jeton valide"        "RSP^K11"    -H "Authorization: Bearer $TOKEN"
show "jeton falsifié"      "Login IRIS" -H "Authorization: Bearer ${TOKEN%?}x"
show "sans jeton"          "Login IRIS"
