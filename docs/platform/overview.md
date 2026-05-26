# Platform Components

## Component Map

Every component in the platform is deployed as an ArgoCD Application. They are organized by sync wave to ensure correct startup order.

| Wave | Component | Namespace | Purpose |
|------|-----------|-----------|---------|
| -1 | Namespaces | — | Creates all required namespaces |
| 0 | kubernetes-replicator | platform | Replicates Secrets/ConfigMaps across namespaces |
| 1 | **Vault** | platform | Secret management (HA 3-node Raft) |
| 1 | **PostgreSQL** | platform | Centralized database with auto-provisioning |
| 1 | **ingress-nginx** | ingress | L7 HTTP gateway |
| 2 | **Authentik** | platform | SSO/OIDC identity provider |
| 2 | **argocd-config** | argocd | ArgoCD ingress, SSO, repo credentials |
| 3 | **Kubrain** | platform | Platform control plane and app hub |
| 3 | **Playhouse** | platform | Browser-accessible dev environments |
| 3 | **CloudBeaver** | platform | Web-based database manager |
| 3 | **Gitea** | platform | Self-hosted Git + OCI registry (Gitea-mode only) |
| 4 | Plugins | varies | Networking, observability, AI (installed separately) |

## Component Details

### Vault

HashiCorp Vault in HA mode (3 replicas, Raft storage).

- **Auto-init/unseal** — CronJob handles unseal after pod restarts
- **Vault Secrets Operator (VSO)** — syncs Vault secrets to Kubernetes Secrets via `VaultStaticSecret` CRDs
- **Auto-provisioning** — CronJob discovers `vault: setup-creds` labeled ConfigMaps and creates policies/roles

**Secrets path structure:**
```
kv-v2/
└── kuberse/
    ├── admin          # Admin credentials
    ├── authentik      # OIDC client secrets
    ├── postgres       # DB passwords
    ├── argocd         # ArgoCD admin + OIDC
    └── <plugin>/      # Per-plugin secrets
```

### PostgreSQL

Single-instance PostgreSQL with automated database provisioning.

- **Auto-provisioning** — A CronJob scans for Secrets labeled `db-provision: "true"` and creates the database + user automatically
- **No manual DB creation** — Charts that need a database ship a labeled Secret; the CronJob handles the rest

### ingress-nginx

Standard ingress controller. All services get HTTPS via cert-manager annotations. Routes are defined by Ingress resources in each service's chart.

### Authentik

Full identity provider with:
- OIDC/OAuth2 for all platform services (ArgoCD, Grafana, Kubrain)
- User management UI
- Flow-based authentication pipelines
- SCIM provisioning (optional)

### ArgoCD Config

Not ArgoCD itself (that's deployed by the CLI), but its **configuration**:
- Ingress for the UI
- SSO integration with Authentik
- Repository credentials for OCI charts
- RBAC policies

### Kubrain

The platform's control plane and user-facing hub:
- Service catalog (Backstage-style entities)
- Documentation portal (renders markdown from repos)
- Plugin management UI
- Remote UI components from plugins (`_app/` template)

### Playhouse

Browser-accessible development environment. Runs OpenCode (AI coding agent) in the cluster, accessible via web terminal.

### CloudBeaver

Web-based database management. Auto-configured to connect to the platform PostgreSQL. Useful for inspecting databases without SSH/port-forward.

### Gitea (Gitea-mode only)

Self-hosted Git server + OCI registry. Used in air-gapped environments where GitHub is not available. The CLI mirrors all charts and images here during setup.

## How Components Discover Secrets

Every component follows the same pattern:

```yaml
# In the Helm chart:
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: my-service-secrets
spec:
  vaultAuthRef: default
  mount: kv-v2
  path: kuberse/my-service
  destination:
    name: my-service-secrets  # K8s Secret created by VSO
    create: true
```

The Vault Secrets Operator watches these CRDs and creates/updates Kubernetes Secrets automatically.

## How Components Get Databases

```yaml
# In the Helm chart:
apiVersion: v1
kind: Secret
metadata:
  name: my-service-db
  labels:
    db-provision: "true"
stringData:
  POSTGRES_DB: my_service
  POSTGRES_USER: my_service
  POSTGRES_PASSWORD_KEY: kuberse/my-service  # Vault path for password
```

The provisioner CronJob creates the database and user in PostgreSQL.

## Adding a New Platform Component

1. Add the subchart to the umbrella chart in `kuberse-helm`
2. Create `platform/my-service/argocd-app.yaml` in this repo:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-service
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: default
  source:
    repoURL: ${REGISTRY_URL}/${ORG_NAME}/charts/platform
    targetRevision: ${PLATFORM_VERSION}
    chart: platform
    helm:
      values: |
        my-service:
          enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: platform
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

3. Commit and push — ArgoCD deploys it automatically.
