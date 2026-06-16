#!/bin/bash
source cloudenv

NAMESPACE=$1
TARGET=${2:-dev-aws}

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
    *)
        echo "Usage: $0 <Namespace> [dev-aws|prod-aws|dev|prod]"
        exit 1
        ;;
esac


# Verify the namespace exists in the target IRIS instance
echo "Verifying namespace '$NAMESPACE' exists in IRIS ..."
VERIFY_CMD="docker exec -i $CONTAINER iris session iris -U %SYS <<'IRISSESSION'
Write ##class(Config.Namespaces).Exists(\"$NAMESPACE\")
halt
IRISSESSION"

if [[ "$TARGET" == *"aws"* ]]; then
    RESULT=$(ssh -i $ACCESS_KEY_FILENAME $CLOUD_USERNAME@$PUBLIC_DNS "$VERIFY_CMD" | tr -d '[:space:]')
else
    RESULT=$(eval "$VERIFY_CMD" | tr -d '[:space:]')
fi

if [[ "$RESULT" == *"1"* ]]; then
    echo "SUCCESS: Namespace '$NAMESPACE' exists in IRIS on container '$CONTAINER' (target: $TARGET)."
else
    echo "ERROR: Namespace '$NAMESPACE' does not exist in IRIS on container '$CONTAINER' (target: $TARGET) (result: '$RESULT')."
    exit 1
fi

echo "Done."

