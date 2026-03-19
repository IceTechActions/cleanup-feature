#!/bin/bash

# ============================================================
# Purge Container Images from ACR
# ============================================================
# Removes container images matching a tag filter from the
# specified repositories in Azure Container Registry.
# Tag filter matching is case-insensitive.
#
# Usage:
#   ./purge-containers.sh <tag-filter> <registry-name> "<repos>"
#
# Arguments:
#   tag-filter    Docker tag pattern (e.g. 'Feature-1234' or 'qa2610-98c2').
#                 Only valid Docker tag characters are allowed: alphanumeric, ., _, -.
#                 Matched case-insensitively — input casing does not matter.
#   registry-name ACR name without .azurecr.io
#   repos         Space-separated list of repository names to purge
#
# Examples:
#   ./purge-containers.sh 'Feature-1234' myregistry "nordic worker"
#   ./purge-containers.sh 'qa2610-98c2' myregistry "nordic worker nis-sql nis-reset-api nis-elastic"
# ============================================================

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <tag-filter> <registry-name> \"<repos>\""
    exit 1
fi

TAG_FILTER=$1
REGISTRY_NAME=$2
REPOS=$3

# Validate TAG_FILTER - allow only valid Docker tag characters (alphanumeric, ., _, -)
if [[ ! "$TAG_FILTER" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Error: TAG_FILTER '${TAG_FILTER}' contains invalid characters. Allowed: alphanumeric, ., _, -"
    exit 1
fi

for REPO in $REPOS; do
    # Validate REPO - allow alphanumeric, dots, hyphens, underscores, and forward slashes (for nested repos)
    if [[ ! "$REPO" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
        echo "Error: Repository name '${REPO}' contains invalid characters. Allowed: alphanumeric, ., _, -, /"
        exit 1
    fi
    echo "Purging repository: $REPO (filter: ${TAG_FILTER} (case-insensitive))"
    PURGE_CMD="acr purge --filter '${REPO}:(?i)${TAG_FILTER}' --filter '${REPO}-.*:(?i)${TAG_FILTER}' --untagged --ago 0d --keep 0"
    az acr run \
        --cmd "$PURGE_CMD" \
        --registry "$REGISTRY_NAME" \
        /dev/null
done
