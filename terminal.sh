#!/bin/bash
source cloudenv

NAMESPACE=${1:-training}
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
    dev-ce)
        CONTAINER="iris-health-training-dev-local"
        ;;
    prod-ce)
        CONTAINER="iris-health-training-prod-local"
        ;;   
    *)
        echo "Usage: $0 [training|user|%sys|<your_namespace>] [dev-aws|prod-aws|dev|prod|dev-ce|prod-ce]"
        exit 1
        ;;
esac

if [[ "$TARGET" == *"aws"* ]]; then
    ssh -t -i $ACCESS_KEY_FILENAME $CLOUD_USERNAME@$PUBLIC_DNS "docker exec -ti $CONTAINER iris session iris -U $NAMESPACE"
else
    docker exec -ti $CONTAINER iris session iris -U $NAMESPACE
fi
