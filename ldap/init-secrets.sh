#!/usr/bin/env bash
# Generates, for the demo OpenLDAP (docker-compose.yml, service "ldap"):
#   ldap/secrets.env                  random passwords (mode 600, git-ignored)
#   ldap/bootstrap/50-iris-demo.ldif  demo users and groups, passwords hashed in SSHA (git-ignored)
# Existing values are never overwritten; the LDIF is only (re)written when it does not exist.
# The LDIF is loaded by the LDAP server at its FIRST start (empty data directory).
#
# Groups follow the InterSystems "universal authorization groups" naming (docs: LDAP Authorization):
#   intersystems-Role-<IRIS role>   -> the members get that IRIS role after an LDAP login
# so that the LDAP users get the very same iris-admin / iris-developer / iris-operator / iris-viewer roles as
# the Keycloak users.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p bootstrap data slapd.d

OUT=secrets.env
rnd() { openssl rand -base64 48 | tr -d '/+=\n' | cut -c1-"${1:-24}"; }
umask 077
[ -f "$OUT" ] || printf '# Generated %s. Never commit this file.\n' "$(date +%Y-%m-%d)" > "$OUT"
get() { grep -m1 "^$1=" "$OUT" | cut -d= -f2- || true; }
add() { if [ -z "$(get "$1")" ]; then printf '%s=%s\n' "$1" "$2" >> "$OUT"; echo "added $1"; fi; }
add LDAP_ADMIN_PASSWORD "$(rnd 24)"
add LDAP_CONFIG_PASSWORD "$(rnd 24)"
add LDAP_READONLY_USER_PASSWORD "$(rnd 24)"      # account used by IRIS to search users and groups
add LDAP_DEMO_USER_PASSWORD "$(rnd 16)"          # password of the demo users
chmod 600 "$OUT"
# REST Client ({{$dotenv VAR}}) reads a file named .env in the folder of the .http file: link it to secrets.env
ln -sf "$OUT" .env

LDIF=bootstrap/50-iris-demo.ldif
if [ -f "$LDIF" ]; then echo "$PWD/$LDIF already exists - kept."; exit 0; fi
PW="$(get LDAP_DEMO_USER_PASSWORD)" python3 - > "$LDIF" <<'PY'
import os,hashlib,base64
base='dc=example,dc=org'
pw=os.environ['PW']
def ssha(p):
    salt=os.urandom(8); return '{SSHA}'+base64.b64encode(hashlib.sha1(p.encode()+salt).digest()+salt).decode()
users=[('ldap.admin','LDAP','Admin','iris-admin'),('ldap.developer','LDAP','Developer','iris-developer'),
       ('ldap.operator','LDAP','Operator','iris-operator'),('ldap.viewer','LDAP','Viewer','iris-viewer')]
out=[f'dn: ou=people,{base}','objectClass: organizationalUnit','ou: people','',
     f'dn: ou=groups,{base}','objectClass: organizationalUnit','ou: groups','']
for uid,given,sn,role in users:
    out+= [f'dn: uid={uid},ou=people,{base}','objectClass: inetOrgPerson','objectClass: organizationalPerson','objectClass: person',
           f'uid: {uid}',f'cn: {given} {sn}',f'sn: {sn}',f'givenName: {given}',f'displayName: {given} {sn}',f'mail: {uid}@example.org',
           f'userPassword: {ssha(pw)}','']
for uid,given,sn,role in users:
    # groupOfUniqueNames / uniqueMember (not groupOfNames / member): that is what the memberof overlay of this OpenLDAP image
    # watches, and IRIS reads the groups of a user from its "memberOf" attribute.
    out+= [f'dn: cn=intersystems-Role-{role},ou=groups,{base}','objectClass: groupOfUniqueNames',f'cn: intersystems-Role-{role}',
           f'description: IRIS role {role} (InterSystems universal authorization group)',f'uniqueMember: uid={uid},ou=people,{base}','']
print('\n'.join(out))
PY
chmod 600 "$LDIF"
echo "Created $PWD/$LDIF and $PWD/$OUT (mode 600). Read the demo password in $OUT (LDAP_DEMO_USER_PASSWORD)."
