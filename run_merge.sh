#!/bin/bash
source .env
source cloudenv

TARGET=${1:-dev-aws}
REMOTE_TMP="/tmp/$CPF_FILE"

case "$TARGET" in
    dev-aws)
        CONTAINER="iris-health-training-dev"
        CPF_FILE="merge-dev.cpf"
        ;;
    prod-aws)
        CONTAINER="iris-health-training-prod"
        CPF_FILE="merge-prod.cpf"
        ;;
    dev)
        CONTAINER="iris-health-training-dev"    
        CPF_FILE="merge-dev.cpf"
        ;;
    prod)
        CONTAINER="iris-health-training-prod"
        CPF_FILE="merge-prod.cpf"
        ;;
    *)
        echo "Usage: $0 <Namespace> [dev-aws|prod-aws|dev|prod] [-y]"
        exit 1
        ;;
esac

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

echo "Done."

