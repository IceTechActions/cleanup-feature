#!/bin/bash

# ============================================================
# Remove Feature Environment Secrets
# ============================================================
# Deletes and purges Key Vault secrets and App Configuration
# entries for a feature environment.
#
# Usage:
#   ./remove-secrets.sh <keyvault-name> <pr-id> [app-config-name]
# ============================================================

KEYVAULT_NAME=$1
PR_ID=$2
APP_CONFIG_NAME=${3:-nis-developers-aac}

if [ -z "$KEYVAULT_NAME" ] || [ -z "$PR_ID" ]; then
    echo "Usage: $0 <keyvault-name> <pr-id> [app-config-name]"
    echo "  app-config-name defaults to 'nis-developers-aac' if not provided"
    exit 1
fi

FEATURE_LABEL="Feature-$PR_ID"

echo "Removing secrets and configs for PR #$PR_ID..."
echo "Using KeyVault: $KEYVAULT_NAME"
echo "Using App Config: $APP_CONFIG_NAME"
echo "Looking for label/prefix: $FEATURE_LABEL"

# Delete all KeyVault secrets with the feature prefix
echo "Deleting KeyVault secrets..."
secrets=$(az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "[?starts_with(name, '$FEATURE_LABEL')].name" -o tsv)
for secret in $secrets; do
    echo "Deleting secret: $secret"
    az keyvault secret delete --vault-name "$KEYVAULT_NAME" --name "$secret" || true
done

# Wait a bit for deletes to complete
echo "Waiting for deletes to complete..."
sleep 7

# Find and purge all deleted secrets with our prefix, including ones from previous runs
echo "Purging all deleted secrets with prefix $FEATURE_LABEL..."
deleted_secrets=$(az keyvault secret list-deleted --vault-name "$KEYVAULT_NAME" --query "[?starts_with(name, '$FEATURE_LABEL')].name" -o tsv)
for secret in $deleted_secrets; do
    echo "Purging secret: $secret"
    az keyvault secret purge --vault-name "$KEYVAULT_NAME" --name "$secret" || true
done

# Delete all App Config entries with the feature label
echo "Deleting App Config entries..."
configs=$(az appconfig kv list --name "$APP_CONFIG_NAME" --label "$FEATURE_LABEL" --query "[].{key:key}" -o tsv)
for config in $configs; do
    echo "Deleting config: $config"
    az appconfig kv delete --name "$APP_CONFIG_NAME" --key "$config" --label "$FEATURE_LABEL" --yes
done

echo "Cleanup completed successfully"
