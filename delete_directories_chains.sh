#!/bin/bash
source .env
source cloudenv

NAMESPACE=$(echo "$1" | tr '[:lower:]' '[:upper:]')
TARGET=${2:-aws}

AUTO_YES=${3:-}

case "$TARGET" in
    aws)
        ;;
    local)
        ;;
    *)
        echo "Usage: $0 <Namespace> [aws|local] [-y]"
        exit 1
        ;;
esac


echo ""
echo "About to delete namespace '$NAMESPACE' on $TARGET"

if [[ "$AUTO_YES" != "-y" ]]; then
    read -r -p "Are you sure? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "Aborted."
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
    echo "Deleting directories chains for $NAMESPACE on $TARGET ..."
    BASE=/home/$CLOUD_USERNAME/intersystems-iris-health-training/data
    ssh -i $ACCESS_KEY_FILENAME $CLOUD_USERNAME@$PUBLIC_DNS "
        rm -rf $BASE/dev/$NAMESPACE  \
               $BASE/prod/$NAMESPACE
    "
else

    echo "Deleting directories chains for $NAMESPACE on $TARGET ..."
    BASE=$PWD/data
    rm -rf $BASE/dev/$NAMESPACE  \
           $BASE/prod/$NAMESPACE
fi

echo "Done."

