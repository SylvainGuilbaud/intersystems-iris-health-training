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
echo "About to create directories chains for $NAMESPACE on $TARGET"
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

    echo "Creating directories chains for $NAMESPACE on $TARGET ..."
    BASE=/home/$CLOUD_USERNAME/intersystems-iris-health-training/data
    ssh -i $ACCESS_KEY_FILENAME $CLOUD_USERNAME@$PUBLIC_DNS "
        mkdir -p $BASE/dev/$NAMESPACE/HL7/ADT/in  \
                 $BASE/dev/$NAMESPACE/HL7/ADT/out  \
                 $BASE/dev/$NAMESPACE/HL7/ADT/work \
                 $BASE/dev/$NAMESPACE/HL7/ORU/in   \
                 $BASE/dev/$NAMESPACE/HL7/ORU/out  \
                 $BASE/dev/$NAMESPACE/HL7/ORU/work \
                 $BASE/dev/$NAMESPACE/HL7/ORU/pdf  \
                 $BASE/prod/$NAMESPACE/HL7/ADT/in  \
                 $BASE/prod/$NAMESPACE/HL7/ADT/out  \
                 $BASE/prod/$NAMESPACE/HL7/ADT/work \
                 $BASE/prod/$NAMESPACE/HL7/ORU/in   \
                 $BASE/prod/$NAMESPACE/HL7/ORU/out  \
                 $BASE/prod/$NAMESPACE/HL7/ORU/work \
                 $BASE/prod/$NAMESPACE/HL7/ORU/pdf
    "
    check "create directories on remote"
else
    echo "Creating directories chains for $NAMESPACE on $TARGET ..."
    BASE=$PWD/data
    mkdir -p $BASE/dev/$NAMESPACE/HL7/ADT/in  \
             $BASE/dev/$NAMESPACE/HL7/ADT/out  \
             $BASE/dev/$NAMESPACE/HL7/ADT/work \
             $BASE/dev/$NAMESPACE/HL7/ORU/in   \
             $BASE/dev/$NAMESPACE/HL7/ORU/out  \
             $BASE/dev/$NAMESPACE/HL7/ORU/work \
             $BASE/dev/$NAMESPACE/HL7/ORU/pdf  \
             $BASE/prod/$NAMESPACE/HL7/ADT/in  \
             $BASE/prod/$NAMESPACE/HL7/ADT/out  \
             $BASE/prod/$NAMESPACE/HL7/ADT/work \
             $BASE/prod/$NAMESPACE/HL7/ORU/in   \
             $BASE/prod/$NAMESPACE/HL7/ORU/out  \
             $BASE/prod/$NAMESPACE/HL7/ORU/work \
             $BASE/prod/$NAMESPACE/HL7/ORU/pdf
    check "create directories locally"
fi

echo "Done."

