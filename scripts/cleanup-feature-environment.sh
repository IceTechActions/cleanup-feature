#!/bin/bash
set -e

# ============================================================
# Cleanup Feature Environment
# ============================================================
# Ordered teardown: FD security policy → route → custom domain →
# origin → origin group → endpoint → DNS CNAME → DNS _dnsauth TXT →
# HttpRouteConfig + Container Apps → hangfire storage → Application Insights
#
# Usage:
#   ./cleanup-feature-environment.sh <feature-name> <resource-group> \
#     [front-door-name] [dns-zone-rg] [dns-zone-name] "<container-apps>"
#
# Arguments:
#   feature-name    Environment name (e.g. feature-1234 or QA2610-98c2)
#   resource-group  Azure resource group containing the environment
#   front-door-name Azure Front Door profile name (default: fd-nisportal)
#   dns-zone-rg     Resource group containing the DNS zone (optional)
#   dns-zone-name   DNS zone name (default: cust.nisportal.com)
#   container-apps  Space-separated list of container app suffixes to delete
#                   (e.g. "nordic worker" or "nordic worker sql redis elastic reset")
# ============================================================

FEATURE_NAME=$1
RESOURCE_GROUP=$2
FRONT_DOOR_NAME=${3:-"fd-nisportal"}
DNS_ZONE_RG=${4:-""}
DNS_ZONE_NAME=${5:-"cust.nisportal.com"}
CONTAINER_APPS=${6:-"nordic worker"}
# Custom domain base used for FD resource name derivation (not the DNS zone name)
CUSTOM_DOMAIN_BASE="cust.nisportal.com"

if [ -z "$FEATURE_NAME" ] || [ -z "$RESOURCE_GROUP" ]; then
    echo "Usage: $0 <feature-name> <resource-group> [front-door-name] [dns-zone-rg] [dns-zone-name] \"<container-apps>\""
    exit 1
fi

echo "============================================"
echo "Cleaning up feature environment: $FEATURE_NAME"
echo "Resource group: $RESOURCE_GROUP"
echo "Front Door: $FRONT_DOOR_NAME"
echo "Container Apps: $CONTAINER_APPS"
echo "============================================"

# 1. [WAF domain disassociation handled by front-door-waf-domain action in action.yml]

# 2. Delete Front Door Route
echo "[2/11] Deleting route..."
az afd route delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --endpoint-name "$FEATURE_NAME" \
  --route-name "default" \
  --yes 2>/dev/null || echo "  Route not found or already deleted"

# 3. Delete Custom Domain
echo "[3/11] Deleting custom domain..."
CUSTOM_DOMAIN_NAME=$(echo "${FEATURE_NAME}-${CUSTOM_DOMAIN_BASE}" | tr '.' '-')
az afd custom-domain delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --custom-domain-name "$CUSTOM_DOMAIN_NAME" \
  --yes --no-wait 2>/dev/null || echo "  Custom domain not found or already deleted"

# 4. Delete Origin
echo "[4/11] Deleting origin..."
az afd origin delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --origin-group-name "${FEATURE_NAME}-origins" \
  --origin-name "routing" \
  --yes 2>/dev/null || echo "  Origin not found or already deleted"

# 5. Delete Origin Group
echo "[5/11] Deleting origin group..."
az afd origin-group delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --origin-group-name "${FEATURE_NAME}-origins" \
  --yes 2>/dev/null || echo "  Origin group not found or already deleted"

# 6. Delete Endpoint
echo "[6/11] Deleting endpoint..."
az afd endpoint delete \
  --profile-name "$FRONT_DOOR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --endpoint-name "$FEATURE_NAME" \
  --yes 2>/dev/null || echo "  Endpoint not found or already deleted"

# 7. Delete DNS CNAME Record
if [ -n "$DNS_ZONE_RG" ]; then
  echo "[7/11] Deleting DNS CNAME record..."
  az network dns record-set cname delete \
    --resource-group "$DNS_ZONE_RG" \
    --zone-name "$DNS_ZONE_NAME" \
    --name "$FEATURE_NAME" \
    --yes 2>/dev/null || echo "  DNS CNAME record not found or already deleted"
else
  echo "[7/11] Skipping DNS CNAME deletion (no DNS_ZONE_RG provided)"
fi

# 8. Delete DNS _dnsauth TXT Record (AFD custom domain validation)
if [ -n "$DNS_ZONE_RG" ]; then
  echo "[8/11] Deleting DNS _dnsauth TXT record..."
  az network dns record-set txt delete \
    --resource-group "$DNS_ZONE_RG" \
    --zone-name "$DNS_ZONE_NAME" \
    --record-set-name "_dnsauth.${FEATURE_NAME}" \
    --yes 2>/dev/null || echo "  DNS _dnsauth TXT record not found or already deleted"
else
  echo "[8/11] Skipping DNS _dnsauth TXT deletion (no DNS_ZONE_RG provided)"
fi

# 9. Delete HttpRouteConfig and Container Apps
echo "[9/11] Deleting HttpRouteConfig and Container Apps..."
CONTAINER_APPS_ENV="feature-environments"
az containerapp env http-route-config delete \
  --http-route-config-name "${FEATURE_NAME}-routing" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CONTAINER_APPS_ENV" \
  --yes 2>/dev/null || echo "  HttpRouteConfig not found or already deleted"
for APP in $CONTAINER_APPS; do
  az containerapp delete --name "${FEATURE_NAME}-${APP}" --resource-group "$RESOURCE_GROUP" --yes 2>/dev/null || true
done

# 10. Delete per-feature storage mounts and storage accounts
echo "[10/11] Deleting per-environment storage..."
CONTAINER_APPS_ENV="feature-environments"
BASE_NAME=$(echo "${FEATURE_NAME}" | tr -d '-')

# Hangfire
az containerapp env storage remove \
  --name "$CONTAINER_APPS_ENV" \
  --resource-group "$RESOURCE_GROUP" \
  --storage-name "${FEATURE_NAME}-hangfire" \
  --yes 2>/dev/null || echo "  Hangfire storage mount not found or already deleted"
az storage account delete \
  --name "${BASE_NAME}storage" \
  --resource-group "$RESOURCE_GROUP" \
  --yes 2>/dev/null || echo "  Hangfire storage account not found or already deleted"

# SQL backup (nis-sql persistent backup volume — QA environments only)
az containerapp env storage remove \
  --name "$CONTAINER_APPS_ENV" \
  --resource-group "$RESOURCE_GROUP" \
  --storage-name "${FEATURE_NAME}-sql-mnt" \
  --yes 2>/dev/null || echo "  SQL mnt-backup storage mount not found or already deleted"
az containerapp env storage remove \
  --name "$CONTAINER_APPS_ENV" \
  --resource-group "$RESOURCE_GROUP" \
  --storage-name "${FEATURE_NAME}-sql-golden" \
  --yes 2>/dev/null || echo "  SQL golden storage mount not found or already deleted"
az storage account delete \
  --name "${BASE_NAME}sqlbak" \
  --resource-group "$RESOURCE_GROUP" \
  --yes 2>/dev/null || echo "  SQL backup storage account not found or already deleted"

# 11. Delete Application Insights and its auto-provisioned alert rule
echo "[11/11] Deleting Application Insights..."
az resource delete \
  --resource-group "$RESOURCE_GROUP" \
  --resource-type "Microsoft.Insights/components" \
  --name "${FEATURE_NAME}-application-insights" \
  2>/dev/null || echo "  Application Insights not found or already deleted"

az resource delete \
  --resource-group "$RESOURCE_GROUP" \
  --resource-type "microsoft.alertsmanagement/smartDetectorAlertRules" \
  --name "Failure Anomalies - ${FEATURE_NAME}-application-insights" \
  2>/dev/null || echo "  Smart Detector Alert Rule not found or already deleted"

echo "============================================"
echo "Cleanup complete for: $FEATURE_NAME"
echo "============================================"
