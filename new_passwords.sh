#!/bin/bash
source .env
source cloudenv


if [ $# -lt 1 ]; then
    echo "Usage: $0 NEW_PASSWORD [dev-aws|prod-aws|dev|prod] [-y]"
    exit 1
fi

NEW_PASSWORD=$1
TARGET=${2:-dev-aws}

CPF_FILE="new_passwords_merge_$(date +%Y%m%d%H%M%S).cpf"
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
        CONTAINER="iris-health-training-prod"
        ;;
    *)
        echo "Usage: $0 NEW_PASSWORD [dev-aws|prod-aws|dev|prod] [-y]"
        exit 1
        ;;
esac

# Generate CPF file dynamically from namespace name
cat > $CPF_FILE <<EOF
[Actions]
Execute:Namespace="TRAINING",ClassName="adm.security",MethodName="setNewPassword",Arg1="Admin",Arg2="${NEW_PASSWORD}"
Execute:Namespace="TRAINING",ClassName="adm.security",MethodName="setNewPassword",Arg1="SuperUser",Arg2="${NEW_PASSWORD}"
Execute:Namespace="TRAINING",ClassName="adm.security",MethodName="setNewPassword",Arg1="_SYSTEM",Arg2="${NEW_PASSWORD}"
EOF

echo "Generated $CPF_FILE for instance $CONTAINER (target: $TARGET)"
echo ""
echo "About to modify users ' on container '$CONTAINER' (target: $TARGET)"
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

echo "Done."

