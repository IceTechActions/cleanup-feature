# cleanup-feature

Removes all Azure resources, Key Vault secrets, App Configuration entries, and container images associated with a feature environment. Performs a safe ordered teardown to respect Azure resource dependencies.

## Prerequisites

- Active Azure CLI session with permissions to delete resources in the target resource group, modify the shared Front Door profile, delete records in the DNS zone, purge Key Vault secrets, and run ACR tasks

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `feature_name` | Yes | Feature environment name to remove, e.g. `feature-1234` |
| `pr_id` | Yes | Pull request number — used to identify Key Vault secrets (`Feature-{pr_id}` prefix) and App Config entries |
| `resource_group` | Yes | Azure resource group containing the feature environment |
| `dns_zone_resource_group` | Yes | Resource group containing the `cust.nisportal.com` DNS zone |
| `keyvault_name` | Yes | Key Vault name from which to delete feature secrets |
| `registry_name` | Yes | Azure Container Registry name (without `.azurecr.io`) from which to purge feature images |

## Usage

```yaml
- name: Azure Login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

- name: Cleanup feature environment
  uses: IceTechActions/cleanup-feature@v1
  with:
    feature_name: feature-1234
    pr_id: 1234
    resource_group: my-resource-group
    dns_zone_resource_group: my-dns-rg
    keyvault_name: my-keyvault
    registry_name: niscontainers
```

## Teardown Order

Resources are deleted in dependency order to avoid Azure API conflicts:

| Step | Resource |
|------|----------|
| 1 | Front Door security policy (WAF association) |
| 2 | Front Door route |
| 3 | Front Door custom domain |
| 4 | Front Door origin |
| 5 | Front Door origin group |
| 6 | Front Door endpoint |
| 7 | DNS CNAME record (`{feature_name}` in `cust.nisportal.com`) |
| 8 | HttpRouteConfig + Nordic and Worker Container Apps |
| 9 | Hangfire storage mount + storage account |
| — | Key Vault secrets with `Feature-{pr_id}` prefix (deleted and purged) |
| — | App Configuration entries with `Feature-{pr_id}` label |
| — | ACR images tagged `*-Feature-{pr_id}` for `nordic` and `worker` repositories |

All steps are idempotent — already-deleted resources are skipped without failing.
