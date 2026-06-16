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
    *)
        echo "Usage: $0 [training|user|%sys|<your_namespace>] [dev-aws|prod-aws|dev|prod]"
        exit 1
        ;;
esac

if [[ "$TARGET" == *"aws"* ]]; then
    ssh -t -i $ACCESS_KEY_FILENAME $CLOUD_USERNAME@$PUBLIC_DNS "docker exec -ti $CONTAINER iris session iris -U $NAMESPACE"
else
    docker exec -ti $CONTAINER iris session iris -U $NAMESPACE
fi
