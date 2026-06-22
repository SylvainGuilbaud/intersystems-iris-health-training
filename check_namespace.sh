#!/bin/bash
set -euo pipefail
source cloudenv

NAMESPACE=${1:-}
TARGET=${2:-dev-aws}

if [[ -z "$NAMESPACE" ]]; then
    echo "Usage: $0 <Namespace> [dev-aws|prod-aws|dev|prod|dev-community|prod-community]"
    exit 1
fi

case "$TARGET" in
    dev-aws)
        CONTAINER="iris-health-training-dev"
        ;;
    prod-aws)
        CONTAINER="iris-health-training-prod"
        ;;
    dev)
        CONTAINER="iris-health-training-dev"
        ;;
    prod)
        CONTAINER="iris-health-training-prod"
        ;;
    dev-community)
        CONTAINER="iris-health-training-dev-community"
        ;;
    prod-community)
        CONTAINER="iris-health-training-prod-community"
        ;;
    *)
        echo "Usage: $0 <Namespace> [dev-aws|prod-aws|dev|prod|dev-community|prod-community]"
        exit 1
        ;;
esac


# Verify the namespace exists in the target IRIS instance
echo "Verifying namespace '$NAMESPACE' exists in IRIS ..."
VERIFY_CMD="docker exec -i $CONTAINER iris session iris -U %SYS <<'IRISSESSION'
Write \"NS_EXISTS=\",##class(Config.Namespaces).Exists(\"$NAMESPACE\"),!
halt
IRISSESSION"

if [[ "$TARGET" == *"aws"* ]]; then
    RESULT=$(ssh -i "$ACCESS_KEY_FILENAME" "$CLOUD_USERNAME@$PUBLIC_DNS" "$VERIFY_CMD" || true)
else
    RESULT=$(eval "$VERIFY_CMD" || true)
fi

EXISTS=$(printf "%s\n" "$RESULT" | grep -Eo 'NS_EXISTS=[01]' | tail -n1 | cut -d= -f2 || true)

if [[ "$EXISTS" == "1" ]]; then
    echo "SUCCESS: Namespace '$NAMESPACE' exists in IRIS on container '$CONTAINER' (target: $TARGET)."
else
    echo "ERROR: Namespace '$NAMESPACE' does not exist in IRIS on container '$CONTAINER' (target: $TARGET)."
    if [[ -z "$EXISTS" ]]; then
        echo "Details: unable to parse NS_EXISTS marker from IRIS output."
        echo "$RESULT"
    fi
    exit 1
fi

echo "Done."

