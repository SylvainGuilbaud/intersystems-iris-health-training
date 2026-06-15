#!/bin/sh
# This script is used to set the correct permissions on the persistent volume 
# in order to allow the IRIS container to read and write to it without issues.

# Get the last directory of $PWD to replace docker_ in volume_name
source .env

# Get the instance name from the first argument 
# If no argument is provided, use the default IRIS instance name from .env
instance_name=${1:-$IRIS_INSTANCE_NAME}

set_permissions() {
    local volume_name="${IRIS_INSTANCE_NAME}_$1"
    local mount_point="/$1"
    docker run --rm -v "${volume_name}:${mount_point}" alpine sh -c \
        "chown -R 51773:51773 ${mount_point} && chmod -R u+rwX,g+rwX ${mount_point}"
}

# Set permissions for the persistent volumes
set_permissions "dev_databases_"$instance_name
set_permissions "databases_"$instance_name
set_permissions "journal_"$instance_name
set_permissions "journal2_"$instance_name
set_permissions "WIJ_"$instance_name    
