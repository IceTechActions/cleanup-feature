#!/bin/bash
set -e

# ============================================================
# Cleanup Feature Environment
# ============================================================
# Ordered teardown: FD security policy → route → custom domain →
# origin → origin group → endpoint → DNS → HttpRouteConfig +
# Container Apps → hangfire storage
#
# Usage:
#   ./cleanup-feature-environment.sh <feature-name> <resource-group> \
#     [front-door-name] [dns-zone-rg] [dns-zone-name]
# ============================================================

FEATURE_NAME=$1
RESOURCE_GROUP=$2
FRONT_DOOR_NAME=${3:-"fd-nisportal"}
DNS_ZONE_RG=${4:-""}
DNS_ZONE_NAME=${5:-"nisportal.com"}
# Custom domain base used for FD resource name derivation (not the DNS zone name)
CUSTOM_DOMAIN_BASE="cust.nisportal.com"

if [ -z "$FEATURE_NAME" ] || [ -z "$RESOURCE_GROUP" ]; then
    echo "Usage: $0 <feature-name> <resource-group> [front-door-name] [dns-zone-rg] [dns-zone-name]"
    exit 1
fi

echo "============================================"
echo "Cleaning up feature environment: $FEATURE_NAME"
echo "Resource group: $RESOURCE_GROUP"
echo "Front Door: $FRONT_DOOR_NAME"
echo "============================================"

# 1. Delete Front Door Security Policy
echo "[1/9] Deleting security policy..."
az afd security-policy delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --security-policy-name "${FEATURE_NAME}-waf" \
  --yes 2>/dev/null || echo "  Security policy not found or already deleted"

# 2. Delete Front Door Route
echo "[2/9] Deleting route..."
az afd route delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --endpoint-name "$FEATURE_NAME" \
  --route-name "default" \
  --yes 2>/dev/null || echo "  Route not found or already deleted"

# 3. Delete Custom Domain
echo "[3/9] Deleting custom domain..."
CUSTOM_DOMAIN_NAME=$(echo "${FEATURE_NAME}-${CUSTOM_DOMAIN_BASE}" | tr '.' '-')
az afd custom-domain delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --custom-domain-name "$CUSTOM_DOMAIN_NAME" \
  --yes 2>/dev/null || echo "  Custom domain not found or already deleted"

# 4. Delete Origin
echo "[4/9] Deleting origin..."
az afd origin delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --origin-group-name "${FEATURE_NAME}-origins" \
  --origin-name "routing" \
  --yes 2>/dev/null || echo "  Origin not found or already deleted"

# 5. Delete Origin Group
echo "[5/9] Deleting origin group..."
az afd origin-group delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --origin-group-name "${FEATURE_NAME}-origins" \
  --yes 2>/dev/null || echo "  Origin group not found or already deleted"

# 6. Delete Endpoint
echo "[6/9] Deleting endpoint..."
az afd endpoint delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --endpoint-name "$FEATURE_NAME" \
  --yes 2>/dev/null || echo "  Endpoint not found or already deleted"

# 7. Delete DNS CNAME Record
if [ -n "$DNS_ZONE_RG" ]; then
  echo "[7/9] Deleting DNS record..."
  az network dns record-set cname delete \
    --resource-group "$DNS_ZONE_RG" \
    --zone-name "$DNS_ZONE_NAME" \
    --name "${FEATURE_NAME}.cust" \
    --yes 2>/dev/null || echo "  DNS record not found or already deleted"
else
  echo "[7/9] Skipping DNS record deletion (no DNS_ZONE_RG provided)"
fi

# 8. Delete HttpRouteConfig and Container Apps
echo "[8/9] Deleting HttpRouteConfig and Container Apps..."
CONTAINER_APPS_ENV="feature-environments"
az containerapp env http-route-config delete \
  --http-route-config-name "${FEATURE_NAME}-routing" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_APPS_ENV" \
  --yes 2>/dev/null || echo "  HttpRouteConfig not found or already deleted"
az containerapp delete --name "${FEATURE_NAME}-nordic" --resource-group "$RESOURCE_GROUP" --yes 2>/dev/null || true
az containerapp delete --name "${FEATURE_NAME}-worker" --resource-group "$RESOURCE_GROUP" --yes 2>/dev/null || true

# 9. Delete per-feature hangfire storage mount and storage account
echo "[9/9] Deleting hangfire storage..."
HANGFIRE_MOUNT_NAME="${FEATURE_NAME}-hangfire"
CONTAINER_APPS_ENV="feature-environments"
az containerapp env storage remove \
  --name "$CONTAINER_APPS_ENV" \
  --resource-group "$RESOURCE_GROUP" \
  --storage-name "$HANGFIRE_MOUNT_NAME" \
  --yes 2>/dev/null || echo "  Hangfire storage mount not found or already deleted"

HANGFIRE_STORAGE_NAME=$(echo "${FEATURE_NAME}" | tr -d '-')storage
az storage account delete \
  --name "$HANGFIRE_STORAGE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --yes 2>/dev/null || echo "  Hangfire storage account not found or already deleted"

echo "============================================"
echo "Cleanup complete for: $FEATURE_NAME"
echo "============================================"
