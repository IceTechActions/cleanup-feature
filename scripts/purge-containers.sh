#!/bin/bash

# ============================================================
# Purge Feature Container Images from ACR
# ============================================================
# Removes Nordic and Worker container images tagged with a
# feature branch pattern from Azure Container Registry.
#
# Usage:
#   ./purge-containers.sh <pull-request-id> <registry-name>
# ============================================================

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <pull_request_id> <registry_name>"
    exit 1
fi

PULL_REQUEST_ID=$1
REGISTRY_NAME=$2

# Purge nordic and customized containers
PURGE_CMD_1="acr purge --filter 'nordic:.*-Feature-${PULL_REQUEST_ID}' --filter 'nordic-.*:.*-Feature-${PULL_REQUEST_ID}' --untagged --ago 0d --keep 0"
az acr run \
    --cmd "$PURGE_CMD_1" \
    --registry "$REGISTRY_NAME" \
    /dev/null

# Purge worker and customized containers
PURGE_CMD_2="acr purge --filter 'worker:.*-Feature-${PULL_REQUEST_ID}' --filter 'worker-.*:.*-Feature-${PULL_REQUEST_ID}' --untagged --ago 0d --keep 0"
az acr run \
    --cmd "$PURGE_CMD_2" \
    --registry "$REGISTRY_NAME" \
    /dev/null
