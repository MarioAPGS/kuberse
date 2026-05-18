# my-plugin

A minimal Kuberse plugin. Deploys a hello-world nginx pod with optional platform integrations.

## Quick start

1. Copy this directory to a new repository
2. Rename `my-plugin` to your plugin name everywhere
3. Replace `YOUR_GITHUB_USERNAME` with your GitHub user/org
4. Push to GitHub -- CI publishes the OCI artifacts automatically

## Local validation

```bash
helm lint src/my-plugin/chart
helm template t src/my-plugin/chart --set hello.enabled=true --debug

# With all integrations enabled:
helm template t src/my-plugin/chart \
  --set hello.enabled=true \
  --set hello.vault.enabled=true \
  --set hello.postgresql.enabled=true \
  --set hello.cloudbeaver.enabled=true \
  --debug
```

## Install

```bash
kuberse plugin install oci://ghcr.io/<owner>/my-plugin-plugin:latest
```

## Platform Integrations

This template includes ready-to-use integration with platform services. Enable them in `values.yaml`:

### Vault (Secret Management)

```yaml
hello:
  vault:
    enabled: true
```

- Creates `VaultConnection`, `VaultAuth`, and `VaultStaticSecret` resources
- Creates a `vault-role-configmap` (label `vault: setup-creds`) for auto-discovery by the Vault CronJob
- The Vault CronJob auto-creates the role and policy -- no manual Vault configuration needed
- Secrets are synced to K8s Secrets and injected as env vars into the deployment

**Required Vault secrets** (see `src/my-plugin/chart/charts/hello/spected-secrets.txt`):
- `secret/hello/config` -- application config secrets
- `secret/hello/db` -- database connection string (if postgresql enabled)

### PostgreSQL (Database)

```yaml
hello:
  postgresql:
    enabled: true
  vault:
    enabled: true  # required: DB credentials come from Vault
```

- The db Secret is labeled `pgdb: PG_CONNECTION_STRING`
- The platform postgres provisioner CronJob discovers it and auto-creates the database + user
- No manual SQL needed -- just seed the connection string in Vault

### CloudBeaver (Web DB Manager)

```yaml
hello:
  cloudbeaver:
    enabled: true
  postgresql:
    enabled: true  # required: CloudBeaver registers the DB connection
  vault:
    enabled: true  # required
```

- The db Secret gets an additional label `cbdb: PG_CONNECTION_STRING`
- The CloudBeaver onboarding CronJob discovers it and auto-registers the connection
- Developers can then browse the database via the CloudBeaver web UI
