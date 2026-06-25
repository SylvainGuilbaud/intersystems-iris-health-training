#!/bin/bash
# This script is used to set the correct permissions on the persistent volume 
# in order to allow the IRIS container to read and write to it without issues.

# Get the last directory of $PWD to replace docker_ in volume_name
source .env

VOLUME_PREFIX="${1:-$IRIS_INSTANCE_NAME}"

echo "Setting permissions on persistent volumes for instance: $VOLUME_PREFIX"

ensure_volume_exists() {
    local volume_name="$1"
    if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
        docker volume create "$volume_name" >/dev/null
    fi
}

set_permissions() {
    local volume_name="${VOLUME_PREFIX}_$1"
    local mount_point="/$1"
    ensure_volume_exists "$volume_name"
    docker run --rm -v "${volume_name}:${mount_point}" alpine sh -c \
        "chown -R 51773:51773 ${mount_point} && chmod -R u+rwX,g+rwX ${mount_point}"
}

# Set permissions for the persistent volumes
set_permissions "dev_databases"
set_permissions "dev_journal"
set_permissions "dev_journal2"
set_permissions "dev_WIJ"
set_permissions "prod_databases"
set_permissions "prod_journal"
set_permissions "prod_journal2"
set_permissions "prod_WIJ"

# Postgres volume is declared as external in docker-compose.yml; create it if missing.
ensure_volume_exists "${VOLUME_PREFIX}_databases_postgreSQL"
