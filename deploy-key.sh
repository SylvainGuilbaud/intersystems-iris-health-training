#!/usr/bin/env bash
# Deploy an InterSystems IRIS license key to the IRIS containers (local and/or AWS).
#
# What it does, for each selected target and instance:
#   1. checks the key file (customer, expiration date) without ever printing the authorization key
#   2. backs up and replaces the host file iris/key/iris.key (mounted as /tmp/iris.key and re-applied
#      by "--key /tmp/iris.key" at every container start)
#   3. backs up and replaces /<ISC_DATA_DIRECTORY>/mgr/iris.key inside the container (the key the
#      running instance reads)
#   4. reloads the license with $SYSTEM.License.Upgrade(); with --restart, restarts IRIS gracefully
#      when the license type changed (Upgrade then answers "requires instance restart")
#
# The host file iris/key/iris.key is shared by the dev and prod containers of a host: replacing it
# affects prod the next time prod restarts, even if only --instance dev is selected.
#
# Usage:
#   ./deploy-key.sh --target local|aws|both [--instance dev|prod|both] [--restart] [--dry-run] [-y] <keyfile>
#
# Examples:
#   ./deploy-key.sh --target local --dry-run iris/key/iris.key
#   ./deploy-key.sh --target aws --instance dev --restart ~/Downloads/new-license.key
#
# Notes:
#   - --dry-run prints what would run and changes nothing.
#   - Keys are never committed: **/*.key and **/*.ISCkey are in .gitignore.

set -euo pipefail
cd "$(dirname "$0")"

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

TARGET=""; INSTANCE="dev"; RESTART=0; DRYRUN=0; YES=0; KEYFILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --target)   TARGET="${2:-}"; shift 2 ;;
        --instance) INSTANCE="${2:-}"; shift 2 ;;
        --restart)  RESTART=1; shift ;;
        --dry-run)  DRYRUN=1; shift ;;
        -y|--yes)   YES=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        -*)         echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)          KEYFILE="$1"; shift ;;
    esac
done

case "$TARGET" in local|aws|both) ;; *) echo "ERROR: --target local|aws|both is required" >&2; usage >&2; exit 1 ;; esac
case "$INSTANCE" in dev|prod|both) ;; *) echo "ERROR: --instance must be dev, prod or both" >&2; exit 1 ;; esac
[ -n "$KEYFILE" ] || { echo "ERROR: key file argument is required" >&2; usage >&2; exit 1; }
[ -f "$KEYFILE" ] || { echo "ERROR: key file not found: $KEYFILE" >&2; exit 1; }

# shellcheck disable=SC1091
source .env
: "${IRIS_INSTANCE_NAME:?IRIS_INSTANCE_NAME missing in .env}"
: "${ISC_DATA_DIRECTORY:?ISC_DATA_DIRECTORY missing in .env}"

# ── Key information (the authorization key itself is never printed) ───────────
field() { grep -m1 "^$1=" "$KEYFILE" | cut -d= -f2- | tr -d '\r' || true; }
LICENSE_ID="$(field LicenseID)"; CUSTOMER="$(field CustomerName)"; ORDER_NO="$(field OrderNumber)"
EXPIRATION="$(field ExpirationDate)"; CAPACITY="$(field LicenseCapacity)"
[ -n "$LICENSE_ID" ] && [ -n "$EXPIRATION" ] || { echo "ERROR: $KEYFILE does not look like an IRIS license key" >&2; exit 1; }

DAYS_LEFT="$(python3 -I -c '
import sys, datetime
d = datetime.datetime.strptime(sys.argv[1], "%m/%d/%Y").date()
print((d - datetime.date.today()).days)' "$EXPIRATION")"

echo "Key file     : $KEYFILE"
echo "License ID   : $LICENSE_ID"
echo "Customer     : $CUSTOMER"
echo "Order        : $ORDER_NO"
echo "Capacity     : $CAPACITY"
echo "Expires      : $EXPIRATION ($DAYS_LEFT day(s) left)"
grep -i "FHIR SQL Builder" "$KEYFILE" | tr -d '\r' | sed 's/^/Feature      : /' || true
if [ "$DAYS_LEFT" -lt 0 ]; then echo "ERROR: this key is already expired" >&2; exit 1; fi
if [ "$DAYS_LEFT" -lt 30 ]; then echo "WARNING: this key expires in less than 30 days"; fi

STAMP="$(date +%Y%m%d-%H%M%S)"
case "$INSTANCE" in
    dev)  SUFFIXES=(dev) ;;
    prod) SUFFIXES=(prod) ;;
    both) SUFFIXES=(dev prod) ;;
esac
TARGETS=(); case "$TARGET" in local) TARGETS=(local) ;; aws) TARGETS=(aws) ;; both) TARGETS=(local aws) ;; esac

echo
echo "Targets      : ${TARGETS[*]}"
echo "Instances    : ${SUFFIXES[*]}   (containers ${IRIS_INSTANCE_NAME}-<instance>)"
echo "Restart IRIS : $([ "$RESTART" = 1 ] && echo yes || echo "no (only if you pass --restart)")"
[ "$DRYRUN" = 1 ] && echo "MODE         : DRY RUN - nothing will be changed"

if [ "$DRYRUN" = 0 ] && [ "$YES" = 0 ]; then
    read -r -p "Deploy this key? [y/N] " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || { echo "Aborted."; exit 1; }
fi

# ── ObjectScript run in %SYS (sent base64-encoded: no quoting issue through ssh) ─
OS_B64="$(printf '%s\n' \
    'set sc=$SYSTEM.License.Upgrade()' \
    'write "upgrade=",sc,!' \
    'write "licensed to: ",$SYSTEM.License.KeyCustomerName()," | order ",$SYSTEM.License.KeyOrderNumber(),!' \
    'halt' | base64 | tr -d '\n')"

# on_host <description>: runs the bash script read on stdin on the target host
on_host() {
    local label="$1" script; script="$(cat)"
    if [ "$DRYRUN" = 1 ]; then
        echo "  [dry-run] $label"; printf '%s\n' "$script" | sed 's/^/      /'; return 0
    fi
    if [ "$CUR" = local ]; then
        bash -s <<<"$script"
    else
        ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" 'bash -s' <<<"$script"
    fi
}

copy_to_host() { # <local file> <path on host>
    if [ "$DRYRUN" = 1 ]; then echo "  [dry-run] copy $1 -> $CUR:$2"; return 0; fi
    if [ "$CUR" = local ]; then cp "$1" "$2"; else scp -q -i "$ACCESS_KEY_FILENAME" "$1" "$CLOUD_USERNAME@$PUBLIC_DNS:$2"; fi
}

deploy_target() {
    CUR="$1"
    echo; echo "=== $CUR ==="
    local REPO_ON_HOST HOST_KEY
    if [ "$CUR" = local ]; then
        REPO_ON_HOST="$PWD"
    else
        # shellcheck disable=SC1091
        source cloudenv
        REPO_ON_HOST="intersystems-iris-health-training"
    fi
    HOST_KEY="$REPO_ON_HOST/iris/key/iris.key"

    # 1. host file used by "--key /tmp/iris.key" at container start
    if [ "$CUR" = local ] && [ "$(cd "$(dirname "$KEYFILE")" && pwd)/$(basename "$KEYFILE")" = "$HOST_KEY" ]; then
        echo "-> iris/key/iris.key is already the key to deploy"
    else
        echo "-> host key file: backup + replace ($HOST_KEY)"
        on_host "backup host key" <<EOF
set -e
[ -f "$HOST_KEY" ] && cp -p "$HOST_KEY" "$HOST_KEY.bak-$STAMP" || true
EOF
        copy_to_host "$KEYFILE" "$HOST_KEY.new-$STAMP"
        on_host "install host key" <<EOF
set -e
mv "$HOST_KEY.new-$STAMP" "$HOST_KEY"
EOF
    fi

    # 2. key read by the running instance, then reload
    for s in "${SUFFIXES[@]}"; do
        local C="${IRIS_INSTANCE_NAME}-$s" MGR="/${ISC_DATA_DIRECTORY}/mgr/iris.key"
        echo "-> container $C: backup + replace $MGR"
        on_host "install key in $C" <<EOF
set -e
docker exec "$C" cp -p "$MGR" "$MGR.bak-$STAMP"
docker cp "$HOST_KEY" "$C:$MGR"
docker exec -u root "$C" chown irisowner:irisowner "$MGR"
EOF
        echo "-> container $C: reload license"
        local RC=0
        on_host "reload license in $C" <<EOF || RC=$?
set +e
OUT=\$(echo '$OS_B64' | base64 -d | docker exec -i "$C" iris session IRIS -U %SYS 2>&1)
echo "\$OUT" | grep -E 'upgrade=|licensed to:' | sed 's/^/   /'
if echo "\$OUT" | grep -q 'requires instance restart'; then
    echo "   NOTE: this license change requires an IRIS restart"
    exit 3
fi
exit 0
EOF
        if [ "$DRYRUN" = 1 ]; then
            echo "  [dry-run] if the license change requires a restart: $([ "$RESTART" = 1 ] && echo "graceful stop + docker restart of $C" || echo "a message tells you to re-run with --restart")"
        elif [ "$RC" = 3 ]; then
            if [ "$RESTART" = 1 ]; then
                echo "-> container $C: graceful IRIS stop, then container restart"
                on_host "restart $C" <<EOF
set -e
docker exec "$C" iris stop IRIS quietly || true
docker restart "$C" >/dev/null
for i in \$(seq 1 36); do
    S=\$(docker inspect --format '{{.State.Health.Status}}' "$C" 2>/dev/null || true)
    [ "\$S" = healthy ] && { echo "   $C is healthy"; exit 0; }
    sleep 5
done
echo "   WARNING: $C is not healthy after 3 minutes (docker ps / docker logs $C)"
EOF
            else
                echo "   -> re-run with --restart, or restart $C yourself:"
                echo "      docker exec $C iris stop IRIS quietly; docker restart $C"
            fi
        elif [ "$RC" != 0 ]; then
            echo "   ERROR: license reload failed on $C (exit $RC)" >&2
            return 1
        fi
    done
}

for t in "${TARGETS[@]}"; do deploy_target "$t"; done
echo; echo "Done. Verify in the Management Portal header (Licensed To), and check the FHIR SQL Builder API if relevant."
