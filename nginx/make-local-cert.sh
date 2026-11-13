#!/usr/bin/env bash
# Creates a self-signed certificate for https://localhost (LOCAL DEV ONLY) in nginx/certs/ (git-ignored).
# For AWS use a real certificate (e.g. Let's Encrypt) - never a self-signed one in front of a login.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p certs
if [ -f certs/localhost.crt ] && [ -f certs/localhost.key ]; then echo "certs/localhost.* already exist."; exit 0; fi
umask 077
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
  -keyout certs/localhost.key -out certs/localhost.crt 2>/dev/null
echo "Created $PWD/certs/localhost.crt and localhost.key (valid 365 days)."
