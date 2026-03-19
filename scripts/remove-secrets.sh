#!/bin/bash

# ============================================================
# Remove Environment Secrets
# ============================================================
# Deletes and purges Key Vault secrets and App Configuration
# entries for a given environment label.
#
# Usage:
#   ./remove-secrets.sh <keyvault-name> <label> [app-config-name]
#
# Examples:
#   ./remove-secrets.sh my-kv Feature-1234
#   ./remove-secrets.sh my-kv QA-QA2610-98c2
# ============================================================

KEYVAULT_NAME=$1
LABEL=$2
APP_CONFIG_NAME=${3:-nis-developers-aac}

if [ -z "$KEYVAULT_NAME" ] || [ -z "$LABEL" ]; then
    echo "Usage: $0 <keyvault-name> <label> [app-config-name]"
    echo "  app-config-name defaults to 'nis-developers-aac' if not provided"
    exit 1
fi

echo "Removing secrets and configs for label: $LABEL"
echo "Using KeyVault: $KEYVAULT_NAME"
echo "Using App Config: $APP_CONFIG_NAME"

# Delete all KeyVault secrets with the label prefix
echo "Deleting KeyVault secrets..."
secrets=$(az keyvault secret list --vault-name "$KEYVAULT_NAME" --query "[?starts_with(name, '$LABEL')].name" -o tsv)
for secret in $secrets; do
    echo "Deleting secret: $secret"
    az keyvault secret delete --vault-name "$KEYVAULT_NAME" --name "$secret" || true
done

# Wait a bit for deletes to complete
echo "Waiting for deletes to complete..."
sleep 7

# Find and purge all deleted secrets with our prefix, including ones from previous runs
echo "Purging all deleted secrets with prefix $LABEL..."
deleted_secrets=$(az keyvault secret list-deleted --vault-name "$KEYVAULT_NAME" --query "[?starts_with(name, '$LABEL')].name" -o tsv)
for secret in $deleted_secrets; do
    echo "Purging secret: $secret"
    az keyvault secret purge --vault-name "$KEYVAULT_NAME" --name "$secret" || true
done

# Delete all App Config entries with the label
echo "Deleting App Config entries..."
configs=$(az appconfig kv list --name "$APP_CONFIG_NAME" --label "$LABEL" --query "[].{key:key}" -o tsv)
for config in $configs; do
    echo "Deleting config: $config"
    az appconfig kv delete --name "$APP_CONFIG_NAME" --key "$config" --label "$LABEL" --yes
done

echo "Cleanup completed successfully"
