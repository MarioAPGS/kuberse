# Platform Architecture

## Overview

Kuberse is a **GitOps-first Kubernetes platform** that packages production infrastructure into a forkable template. The platform follows a layered architecture where each layer depends only on the layers below it.

```mermaid
graph TB
    subgraph User["User's Machine"]
        CLI[kuberse CLI]
    end

    subgraph Cluster["Kubernetes Cluster"]
        subgraph Wave1["Wave 1 — Foundation"]
            Vault[Vault<br/>Secrets]
            PG[PostgreSQL<br/>Databases]
            Ingress[ingress-nginx<br/>HTTP Gateway]
        end

        subgraph Wave2["Wave 2 — Identity & GitOps"]
            Authentik[Authentik<br/>SSO/OIDC]
            ArgoCD[ArgoCD<br/>GitOps Engine]
            Replicator[Replicator<br/>Cross-NS Secrets]
        end

        subgraph Wave3["Wave 3 — Applications"]
            Kubrain[Kubrain<br/>Control Plane]
            Playhouse[Playhouse<br/>Dev Environments]
            CloudBeaver[CloudBeaver<br/>DB Manager]
        end

        subgraph Plugins["Plugins (optional)"]
            Net[Networking<br/>Cloudflare Tunnel]
            Obs[Observability<br/>Grafana + Loki + Mimir]
            AI[AI Infra<br/>LiteLLM + Agents]
        end
    end

    subgraph External["External Services"]
        CF[Cloudflare<br/>DNS + Tunnel]
        GH[GitHub/Gitea<br/>Git + OCI Registry]
    end

    CLI -->|"kuberse init"| Cluster
    CLI -->|"kuberse setup"| Vault
    CLI -->|"kuberse setup"| ArgoCD
    ArgoCD -->|"reconciles"| Wave1
    ArgoCD -->|"reconciles"| Wave2
    ArgoCD -->|"reconciles"| Wave3
    ArgoCD -->|"reconciles"| Plugins
    Vault -.->|"provides secrets"| Wave2
    Vault -.->|"provides secrets"| Wave3
    Vault -.->|"provides secrets"| Plugins
    PG -.->|"provides databases"| Authentik
    PG -.->|"provides databases"| Kubrain
    Ingress -->|"routes traffic"| Wave3
    Net -->|"exposes cluster"| CF
    ArgoCD -->|"pulls charts from"| GH
```

## Design Principles

1. **Vault-first** — Vault is deployed and seeded by the CLI *before* ArgoCD exists. This eliminates secret race conditions. Every other component pulls secrets via `VaultStaticSecret` CRDs.

2. **Umbrella chart pattern** — One OCI Helm chart per category (platform, runners, buildapp) with all subcharts disabled by default. Each ArgoCD Application enables exactly one subchart. This means adding a service requires zero chart changes — only a new ArgoCD Application manifest in this repo.

3. **Three-level app-of-apps** — `bootstrap.yaml` → category app-of-apps → individual Applications. ArgoCD auto-discovers new services by scanning directories.

4. **Template-driven personalization** — All manifests use `${PLACEHOLDER}` tokens that the CLI resolves during setup. After resolution, the repo contains valid YAML that ArgoCD can apply directly.

5. **Plugin extensibility** — New capabilities ship as OCI artifacts (chart + manifests). The CLI mirrors them to the user's registry and injects resolved manifests into this repo. ArgoCD does the rest.

## Data Flows

### Secret Provisioning

```mermaid
sequenceDiagram
    participant CLI as kuberse CLI
    participant Vault as Vault
    participant VSO as Vault Secrets Operator
    participant App as Application Pod

    CLI->>Vault: kuberse secrets seed (write secrets)
    Note over Vault: Stores in kv-v2/kuberse/*
    
    App->>App: Deploys with VaultStaticSecret CRD
    VSO->>Vault: Reads secret path from CRD
    VSO->>App: Creates Kubernetes Secret
    App->>App: Mounts secret as env/volume
```

### Database Auto-Provisioning

```mermaid
sequenceDiagram
    participant Chart as Helm Chart
    participant CronJob as DB Provisioner CronJob
    participant PG as PostgreSQL

    Chart->>Chart: Deploys Secret labeled db-provision=true
    CronJob->>CronJob: Runs every 5 min, discovers labeled Secrets
    CronJob->>PG: CREATE DATABASE + CREATE USER
    Note over PG: Database ready for app
```

### Plugin Installation

```mermaid
sequenceDiagram
    participant User as User
    participant CLI as kuberse CLI
    participant OCI as OCI Registry
    participant Repo as This Registry Repo
    participant Argo as ArgoCD

    User->>CLI: kuberse plugin install kuberse-networking
    CLI->>OCI: oras pull (manifest artifact)
    CLI->>OCI: helm pull (chart)
    CLI->>OCI: Mirror chart to user's registry
    CLI->>Repo: Copy manifests to plugins/kuberse-networking/
    CLI->>Repo: Resolve ${PLACEHOLDERS}
    CLI->>Repo: git commit + push
    Argo->>Repo: Detects change
    Argo->>OCI: Pulls chart
    Argo->>Argo: Deploys plugin
```

## Network Topology

```
Internet
  │
  ├─ Cloudflare DNS (*.your-domain.com)
  │     │
  │     ▼
  ├─ Cloudflare Tunnel (outbound-only from cluster)
  │     │
  │     ▼
  └─ ingress-nginx (in-cluster L7 router)
        │
        ├─ argocd.your-domain.com    → ArgoCD Server
        ├─ vault.your-domain.com     → Vault UI
        ├─ auth.your-domain.com      → Authentik
        ├─ kubrain.your-domain.com   → Kubrain App
        ├─ grafana.your-domain.com   → Grafana (plugin)
        └─ *.your-domain.com         → Other services
```

## Technology Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Secrets | HashiCorp Vault (HA Raft) | Zero-trust, dynamic credentials, audit log |
| GitOps | ArgoCD | Declarative, auto-sync, health checks, RBAC |
| Identity | Authentik | Full OIDC provider, self-hosted, SCIM |
| Database | PostgreSQL (HA) | Reliable, auto-provisioned per service |
| Ingress | ingress-nginx | Industry standard, annotation-driven |
| Tunnel | Cloudflare Tunnel | No open ports, DDoS protection, Zero Trust |
| Monitoring | Grafana + Loki + Mimir | Unified logs/metrics, lightweight |
| Charts | Helm + OCI | Versioned, reproducible, registry-native |
| CI | GitHub Actions | Native, with self-hosted runners in-cluster |
