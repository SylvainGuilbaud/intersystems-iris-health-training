#!/bin/bash
# This script is used to set the correct permissions on the persistent volume 
# in order to allow the IRIS container to read and write to it without issues.

# Get the last directory of $PWD to replace docker_ in volume_name
source .env

echo "Setting permissions on persistent volumes for instance: $IRIS_INSTANCE_NAME"

set_permissions() {
    local volume_name="${IRIS_INSTANCE_NAME}_$1"
    local mount_point="/$1"
    docker run --rm -v "${volume_name}:${mount_point}" alpine sh -c \
        "chown -R 51773:51773 ${mount_point} && chmod -R u+rwX,g+rwX ${mount_point}"
}

# Set permissions for the persistent volumes
set_permissions "dev_databases_"$IRIS_INSTANCE_NAME
set_permissions "databases_"$IRIS_INSTANCE_NAME
set_permissions "journal_"$IRIS_INSTANCE_NAME
set_permissions "journal2_"$IRIS_INSTANCE_NAME
set_permissions "WIJ_"$IRIS_INSTANCE_NAME    
