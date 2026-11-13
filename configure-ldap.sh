#!/usr/bin/env bash
# Applies (or re-applies) the native LDAP authentication/authorization of the IRIS instances - see iris/src/adm/ldap.cls.
# The password of the account that searches the directory is read from ldap/secrets.env (LDAP_READONLY_USER_PASSWORD)
# and sent to IRIS at run time: it is not in the image nor in the repository, so iris.script does not call adm.ldap and
# this script must be run after the containers (and their LDAP server) exist. Idempotent.
#
# Usage: ./configure-ldap.sh [--target local|aws] [--instance dev|prod|both] [--apps none|default] [--dry-run]
#   --apps none     only the LDAP configuration and the default domain: no web application is modified (first step, safe)
#   --apps default  also enables LDAP on the web applications listed in adm.ldap (the portal)
#   local: prompts for an IRIS user/password (or set IRIS_LOGIN_USER and IRIS_LOGIN_PASSWORD)
#   aws:   runs over ssh (cloudenv); the secrets are read on the host
set -euo pipefail
cd "$(dirname "$0")"

TARGET=local; INSTANCE=dev; APPS=default; DRYRUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --target)   TARGET="${2:-}"; shift 2 ;;
        --instance) INSTANCE="${2:-}"; shift 2 ;;
        --apps)     APPS="${2:-}"; shift 2 ;;
        --dry-run)  DRYRUN=1; shift ;;
        -h|--help)  sed -n '2,/^set /p' "$0" | sed 's/^# \{0,1\}//' | head -n -1; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done
case "$TARGET" in local|aws) ;; *) echo "ERROR: --target local|aws" >&2; exit 1 ;; esac
case "$INSTANCE" in dev) S=(dev) ;; prod) S=(prod) ;; both) S=(dev prod) ;; *) echo "ERROR: --instance dev|prod|both" >&2; exit 1 ;; esac
case "$APPS" in none|default) ;; *) echo "ERROR: --apps none|default" >&2; exit 1 ;; esac
# shellcheck disable=SC1091
source .env

APPARG='##class(adm.ldap).#WEBAPPS'; [ "$APPS" = none ] && APPARG='""'

# build the ObjectScript with the secret inside: base64 keeps it out of any quoting problem and out of the process list
mk_os() { # $1 = LDAP search password
    local pw64; pw64="$(printf '%s' "$1" | base64 | tr -d '\n')"
    printf '%s\n' \
        'zn "COMMON"' \
        'set sc=$SYSTEM.OBJ.Load("/code/adm/ldap.cls","ck")' \
        "set pw=\$SYSTEM.Encryption.Base64Decode(\"$pw64\")" \
        "set sc=##class(adm.ldap).Configure(pw,$APPARG)" \
        'halt'
}

if [ "$TARGET" = local ]; then
    [ "$DRYRUN" = 1 ] || { : "${IRIS_LOGIN_USER:=}"
        [ -n "$IRIS_LOGIN_USER" ] || read -r -p "IRIS user: " IRIS_LOGIN_USER
        [ -n "${IRIS_LOGIN_PASSWORD:-}" ] || { read -r -s -p "IRIS password: " IRIS_LOGIN_PASSWORD; echo; }; }
    LDAP_PW="$(grep -m1 '^LDAP_READONLY_USER_PASSWORD=' ldap/secrets.env | cut -d= -f2-)"
    [ -n "$LDAP_PW" ] || { echo "ERROR: LDAP_READONLY_USER_PASSWORD missing in ldap/secrets.env (./ldap/init-secrets.sh)" >&2; exit 1; }
else
    # shellcheck disable=SC1091
    source cloudenv
fi

for s in "${S[@]}"; do
    C="${IRIS_INSTANCE_NAME}-$s"
    echo "=== $TARGET / $C  (web applications: $APPS)"
    if [ "$DRYRUN" = 1 ]; then echo "  [dry-run] iris session IRIS -U %SYS in $C: load /code/adm/ldap.cls; adm.ldap.Configure(<password from ldap/secrets.env>, $APPARG)"; continue; fi
    if [ "$TARGET" = local ]; then
        { printf '%s\n%s\n' "$IRIS_LOGIN_USER" "$IRIS_LOGIN_PASSWORD"; mk_os "$LDAP_PW"; } | docker exec -i "$C" iris session IRIS -U %SYS 2>&1
    else
        # the password is read on the host, never on this machine
        REMOTE_PW="$(ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" "grep -m1 '^LDAP_READONLY_USER_PASSWORD=' intersystems-iris-health-training/ldap/secrets.env | cut -d= -f2-")"
        [ -n "$REMOTE_PW" ] || { echo "ERROR: LDAP_READONLY_USER_PASSWORD missing on the host" >&2; exit 1; }
        mk_os "$REMOTE_PW" | ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" "docker exec -i $C iris session IRIS -U %SYS" 2>&1
        unset REMOTE_PW
    fi | grep -vE '^$|Node:|Username:|Password:|^[A-Za-z0-9._-]+:[A-Z%]+>$' | sed -E 's/^[A-Za-z0-9._-]+:[A-Z%]+>//' | grep -v '^$'
done
