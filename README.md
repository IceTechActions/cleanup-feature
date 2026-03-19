# cleanup-feature

Removes all Azure resources, Key Vault secrets, App Configuration entries, and container images associated with a feature or QA environment. Performs a safe ordered teardown to respect Azure resource dependencies.

## Prerequisites

- Active Azure CLI session with permissions to delete resources in the target resource group, modify the shared Front Door profile, delete records in the DNS zone, purge Key Vault secrets, and run ACR tasks

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `feature_name` | Yes | — | Feature environment name to remove, e.g. `feature-1234` |
| `resource_group` | Yes | — | Azure resource group containing the feature environment |
| `dns_zone_resource_group` | Yes | — | Resource group containing the DNS zone |
| `keyvault_name` | Yes | — | Key Vault name for feature secrets and credential retrieval |
| `registry_name` | Yes | — | Azure Container Registry name (without `.azurecr.io`) |
| `sql_managed_instance` | Yes | — | SQL Managed Instance name for deleting the feature database |
| `sql_managed_instance_resource_group` | Yes | — | Resource group containing the SQL Managed Instance |
| `elastic8_endpoint` | Yes | — | Elasticsearch 8 endpoint URL for deleting feature indices |
| `secrets_label` | Yes | — | Label for Key Vault secrets and App Config entries, e.g. `Feature-1234` or `QA-QA2610-98c2` |
| `image_tag_filter` | Yes | — | ACR tag regex filter for images to purge, e.g. `.*-Feature-1234` or `QA2610-98c2` |
| `image_repos` | Yes | — | Space-separated list of ACR repository names to purge, e.g. `nordic worker` |
| `container_apps` | Yes | — | Space-separated list of Container App name suffixes to delete, e.g. `nordic worker` |
| `front_door_name` | No | `fd-nisportal` | Azure Front Door profile name |
| `dns_zone_name` | No | `cust.nisportal.com` | DNS zone name |
| `skip_sqlmi` | No | `false` | Skip SQL Managed Instance database deletion (set `true` for environments with containerised SQL) |
| `skip_redis_cleanup` | No | `false` | Skip Redis key cleanup (set `true` for environments with containerised Redis) |
| `skip_elastic_cleanup` | No | `false` | Skip Elasticsearch index cleanup (set `true` for environments with containerised Elastic) |

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
    resource_group: my-resource-group
    dns_zone_resource_group: my-dns-rg
    keyvault_name: my-keyvault
    registry_name: niscontainers
    sql_managed_instance: my-sqlmi
    sql_managed_instance_resource_group: my-sqlmi-rg
    elastic8_endpoint: https://my-elastic.example.com
    secrets_label: Feature-1234
    image_tag_filter: .*-Feature-1234
    image_repos: nordic worker
    container_apps: nordic worker
```

## Teardown Order

Resources are deleted in dependency order to avoid Azure API conflicts:

| Step | Resource |
|------|----------|
| 1 | Disassociate custom domain from shared Front Door WAF security policy |
| 2 | Front Door route |
| 3 | Front Door custom domain |
| 4 | Front Door origin |
| 5 | Front Door origin group |
| 6 | Front Door endpoint |
| 7 | DNS CNAME record (`{feature_name}` in DNS zone) |
| 8 | DNS `_dnsauth.{feature_name}` TXT record (AFD custom domain validation) |
| 9 | HttpRouteConfig + Container Apps |
| 10 | Hangfire storage mount + storage account |
| — | Key Vault secrets matching `secrets_label` (deleted and purged) |
| — | App Configuration entries matching `secrets_label` label |
| — | ACR images matching `image_tag_filter` in `image_repos` repositories |
| — | SQL Managed Instance database (unless `skip_sqlmi` is `true`) |
| — | Redis keys (unless `skip_redis_cleanup` is `true`) |
| — | Elasticsearch indices (unless `skip_elastic_cleanup` is `true`) |

All steps are idempotent — already-deleted resources are skipped without failing.
