# Vault

## Role in the Platform

Vault is the **first service deployed** — even before ArgoCD. It provides secrets to every other component via the Vault Secrets Operator (VSO).

## Architecture

- **3-node HA Raft** — Fault tolerant, no external storage dependency
- **Auto-unseal** — CronJob handles unseal after pod restarts
- **Vault Secrets Operator** — Watches `VaultStaticSecret` CRDs and creates Kubernetes Secrets

## Secret Path Convention

```
kv-v2/kuberse/
├── admin              # Unified admin credentials
├── argocd             # ArgoCD OIDC + admin password
├── authentik          # Authentik secret key + OIDC secrets
├── postgres           # Superuser + per-service passwords
├── cloudflare         # Tunnel token (networking plugin)
├── grafana            # Admin password (observability plugin)
├── ai                 # API keys (AI plugin)
└── <custom>/          # Your app secrets
```

## Auto-Provisioning

A CronJob (`vault-module-config`) runs every 5 minutes and:
1. Discovers ConfigMaps labeled `vault: setup-creds`
2. Creates Vault policies allowing read access to the specified path
3. Creates Kubernetes auth roles bound to the service's namespace/ServiceAccount

This means new services get Vault access automatically — just ship a labeled ConfigMap in your chart.

## Seeding Secrets

```bash
# Interactive — discovers what's needed
kuberse secrets seed

# Scope to a specific module
kuberse secrets seed --scope=cloudflare
```

## Accessing Vault UI

```
https://vault.${BASE_DOMAIN}
```

Login with the root token (stored in the CLI pod at `/workspace/.vault-token` during setup).
