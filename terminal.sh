#!/bin/bash

TARGET=${1:-iris}

case "$TARGET" in
    iris)
        CONTAINER="iris-health-training"
        ;;
    prod1)
        CONTAINER="iris-prod-1"
        ;;
    prod2)
        CONTAINER="iris-prod-2"
        ;;
    *)
        echo "Usage: $0 [iris|prod1|prod2]"
        exit 1
        ;;
esac

docker exec -it "$CONTAINER" iris session iris -U SC