#!/bin/bash
source .env
source cloudenv

NAMESPACE=$(echo "$1" | tr '[:lower:]' '[:upper:]')
TARGET=${2:-dev-aws}
CPF_FILE="create_namespace_merge_${NAMESPACE}_$(date +%Y%m%d%H%M%S).cpf"
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
        echo "Usage: $0 <Namespace> [dev-aws|prod-aws|dev|prod] [-y]"
        exit 1
        ;;
esac

# Generate CPF file dynamically from namespace name
cat > $CPF_FILE <<EOF
[Actions]
CreateResource:Name=%DB_${NAMESPACE}_DATA,Description="${NAMESPACE}_DATA database"
CreateDatabase:Name=${NAMESPACE}_DATA,Directory=/${ISC_DATA_DIRECTORY}/mgr/${NAMESPACE}_DATA,Resource=%DB_${NAMESPACE}_DATA
CreateResource:Name=%DB_${NAMESPACE}_CODE,Description="${NAMESPACE}_CODE database"
CreateDatabase:Name=${NAMESPACE}_CODE,Directory=/${ISC_DATA_DIRECTORY}/mgr/${NAMESPACE}_CODE,Resource=%DB_${NAMESPACE}_CODE
CreateNamespace:Name=${NAMESPACE},Globals=${NAMESPACE}_DATA,Routines=${NAMESPACE}_CODE,Interop=1
CreateRole:Name=${NAMESPACE}_ROLE,Description="Role for ${NAMESPACE} namespace",Resources=%DB_${NAMESPACE}_DATA,%DB_${NAMESPACE}_CODE
CreateUser:Name=${NAMESPACE},NameSpace=${NAMESPACE},FullName=TECHNIDATA,AccountNeverExpires=1,PasswordNeverExpires=1,Roles=%All,${NAMESPACE}_ROLE,PasswordHash=4c458bac977abcc5c5537edca92bd3789eab4c8bc3af70874966c35a0947f0d358591e85f176d2c6d06b7e41ba439cdd91f0b6f42c541f906656852d1e4456a1,b0da7a46afc5af0d44da87452b85e5cefb9fe02aa01706cf501f1a168babaab78fef063c5a577e8228d6fcc0f3961363c9906d39cc689e5a264c447a0fff3692,10000,SHA512
EOF

echo "Generated $CPF_FILE for namespace $NAMESPACE"
echo ""
echo "About to create namespace '$NAMESPACE' on container '$CONTAINER' (target: $TARGET)"
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

# Verify the namespace exists in the target IRIS instance
./check_namespace.sh $NAMESPACE $TARGET

echo "Done."

