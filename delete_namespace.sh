#!/bin/bash
source .env
source cloudenv

NAMESPACE=$(echo "$1" | tr '[:lower:]' '[:upper:]')
NAMESPACE_APP=$(echo "$1" | tr '[:upper:]' '[:lower:]')
TARGET=${2:-dev-aws}
CPF_FILE="delete_namespace_merge_${NAMESPACE}_$(date +%Y%m%d%H%M%S).cpf"
REMOTE_TMP="/tmp/$CPF_FILE"

AUTO_YES=${3:-}

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
        CONTAINER="iris-health-training"
        ;;
    *)
        echo "Usage: $0 <Namespace> [dev-aws|prod-aws|dev|prod]"
        exit 1
        ;;
esac

# Generate CPF file dynamically from namespace name
cat > $CPF_FILE <<EOF
[Actions]
DeleteDatabase:Name=${NAMESPACE}_DATA,Directory=/${ISC_DATA_DIRECTORY}/mgr/${NAMESPACE}_DATA
DeleteDatabase:Name=${NAMESPACE}_CODE,Directory=/${ISC_DATA_DIRECTORY}/mgr/${NAMESPACE}_CODE
DeleteNamespace:Name=${NAMESPACE}
DeleteResource:Name=%DB_${NAMESPACE}_DATA
DeleteResource:Name=%DB_${NAMESPACE}_CODE
DeleteApplication:Name=/csp/healthshare/${NAMESPACE_APP}	
DeleteApplication:Name=/csp/healthshare/${NAMESPACE_APP}/bulkfhir	
DeleteApplication:Name=/csp/healthshare/${NAMESPACE_APP}/bulkfhir/api	
DeleteApplication:Name=/csp/healthshare/${NAMESPACE_APP}/services
DeleteRole:Name=${NAMESPACE}_ROLE
DeleteUser:Name=${NAMESPACE}
EOF

echo "Generated $CPF_FILE for namespace $NAMESPACE"
echo ""
echo "About to delete namespace '$NAMESPACE' on container '$CONTAINER' (target: $TARGET)"

if [[ "$AUTO_YES" != "-y" ]]; then
    read -r -p "Are you sure? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "Aborted."
        rm -f "$CPF_FILE"
        exit 0
    fi
fi

check() {
    if [ $? -ne 0 ]; then
        echo "ERROR: $1 failed. Aborting."
        exit 1
    fi
    echo "OK: $1"
}

if [[ "$TARGET" == *"aws"* ]]; then
    echo "Copying $CPF_FILE to $CLOUD_USERNAME@$PUBLIC_DNS:$REMOTE_TMP ..."
    scp -i $ACCESS_KEY_FILENAME $CPF_FILE $CLOUD_USERNAME@$PUBLIC_DNS:$REMOTE_TMP
    check "scp $CPF_FILE to remote host"

    echo "Copying $CPF_FILE into container $CONTAINER ..."
    ssh -i $ACCESS_KEY_FILENAME $CLOUD_USERNAME@$PUBLIC_DNS "docker cp $REMOTE_TMP $CONTAINER:$REMOTE_TMP"
    check "docker cp into container"

    echo "Running iris merge on $CONTAINER ..."
    ssh -i $ACCESS_KEY_FILENAME $CLOUD_USERNAME@$PUBLIC_DNS "docker exec $CONTAINER iris merge iris $REMOTE_TMP"
    check "iris merge"
else
    echo "Copying $CPF_FILE into container $CONTAINER ..."
    docker cp $CPF_FILE $CONTAINER:$REMOTE_TMP
    check "docker cp into container"

    echo "Running iris merge on $CONTAINER ..."
    docker exec $CONTAINER iris merge iris $REMOTE_TMP
    check "iris merge"
fi

rm -f "$CPF_FILE"

# Verify the namespace no longer exists in the target IRIS instance
echo "Verifying namespace '$NAMESPACE' no longer exists in IRIS ..."
echo "Running check_namespace.sh $NAMESPACE $TARGET ..."
echo "this should fail with an error message indicating the namespace does not exist."
./check_namespace.sh $NAMESPACE $TARGET

echo "Done."

