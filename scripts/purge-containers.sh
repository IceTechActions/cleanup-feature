#!/bin/bash

# ============================================================
# Purge Container Images from ACR
# ============================================================
# Removes container images matching a tag filter from the
# specified repositories in Azure Container Registry.
#
# Usage:
#   ./purge-containers.sh <tag-filter> <registry-name> "<repos>"
#
# Arguments:
#   tag-filter    ACR tag regex (e.g. '.*-Feature-1234' or 'QA2610-98c2')
#   registry-name ACR name without .azurecr.io
#   repos         Space-separated list of repository names to purge
#
# Examples:
#   ./purge-containers.sh '.*-Feature-1234' myregistry "nordic worker"
#   ./purge-containers.sh 'QA2610-98c2' myregistry "nordic worker nis-sql nis-reset-api nis-elastic"
# ============================================================

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <tag-filter> <registry-name> \"<repos>\""
    exit 1
fi

TAG_FILTER=$1
REGISTRY_NAME=$2
REPOS=$3

for REPO in $REPOS; do
    echo "Purging repository: $REPO (filter: ${TAG_FILTER})"
    PURGE_CMD="acr purge --filter '${REPO}:${TAG_FILTER}' --filter '${REPO}-.*:${TAG_FILTER}' --untagged --ago 0d --keep 0"
    az acr run \
        --cmd "$PURGE_CMD" \
        --registry "$REGISTRY_NAME" \
        /dev/null
done
