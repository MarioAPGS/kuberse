# ArgoCD

## Role in the Platform

ArgoCD is the **GitOps engine** that keeps the cluster in sync with this repository. It is deployed by the CLI during `kuberse setup` and then manages itself (and everything else) via the app-of-apps pattern.

## How It's Configured

ArgoCD itself is deployed by the CLI, but its **configuration** (ingress, SSO, repo credentials) is managed as a platform component at `platform/argocd-config/`.

This includes:
- Ingress for the UI (`argocd.${BASE_DOMAIN}`)
- OIDC integration with Authentik
- OCI registry credentials for pulling charts
- RBAC policies

## Key Behaviors

| Setting | Value | Why |
|---------|-------|-----|
| Auto-sync | Enabled | Changes propagate without manual approval |
| Self-heal | Enabled | Manual cluster edits get reverted |
| Prune | Enabled | Deleted manifests = deleted resources |
| ServerSideApply | Required | Handles large CRDs and ownership conflicts |
| Sync waves | Used | Controls deployment order |

## Accessing the UI

```
https://argocd.${BASE_DOMAIN}
```

Login via Authentik SSO (or with admin password from Vault at `kuberse/argocd`).

## Troubleshooting

- **App shows `Unknown`** — Wait 3 minutes for the sync cycle, or click Refresh
- **OIDC login fails** — See [Troubleshooting](../cli/troubleshooting.md#argocd-oidc-login-fails-html-instead-of-json)
- **Can't pull charts** — Check registry credentials: `kubectl -n argocd get secret ghcr-oci-creds`
