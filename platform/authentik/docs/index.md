# Authentik

> Centralized SSO/Identity Provider with decentralized OIDC provisioning and Vault integration.

| Property | Value |
|----------|-------|
| **Chart** | `platform/authentik/` |
| **Sync Wave** | 1 |
| **Namespace** | `platform` |
| **Image** | `ghcr.io/goauthentik/server:latest` |
| **Dependencies** | Vault (Wave 1), PostgreSQL (Wave 1), Ingress NGINX (Wave 1) |
| **URL** | `https://auth.kuberse.net` |

## Overview

Authentik is the centralized identity provider for the Kuberse platform. It provides SSO (Single Sign-On) via OIDC for all platform services that need user authentication (ArgoCD, Grafana, Kiops, etc.).

The module deploys three components:
- **Server** -- Django application serving the admin UI and OIDC/SAML endpoints
- **Worker** -- Celery background task processor
- **Redis** -- In-memory cache/broker for task queue and sessions

The key architectural feature is **decentralized OIDC provisioning**: each module that needs OIDC declares its requirements via a labeled ConfigMap, and an automated PostSync Job discovers these configs, creates providers/applications in Authentik, and writes the resulting credentials (`clientID`, `clientSecret`) to each module's Vault path.

## Architecture

```mermaid
graph TB
    subgraph "Platform Namespace"
        subgraph "Authentik Pod"
            INIT["Init Container<br/>wait-for-db"]
            SERVER["Authentik Server<br/>(Django, port 9000)"]
            WORKER["Authentik Worker<br/>(Celery)"]
        end
        REDIS["Redis 7<br/>(cache/broker)"]

        subgraph "Secrets"
            KC["kuberse-config<br/>(admin_password, admin_email)"]
            US["authentik-secrets<br/>(SECRET_KEY, BOOTSTRAP_TOKEN,<br/>PG_CONNECTION_STRING, PG_PASSWORD)<br/>labels: pgdb, cbdb"]
        end

        subgraph "OIDC Provisioner"
            JOB["PostSync Job<br/>provision-oidc.py"]
            BP["Blueprints ConfigMap<br/>(groups, scope mappings)"]
        end

        SVC["Service authentik-server<br/>:9000 / :9443"]
        ING["Ingress<br/>auth.kuberse.net"]
    end

    subgraph "Vault"
        VMAIN["secret/authentik/main"]
        VO["secret/argocd/oidc<br/>secret/grafana/oidc<br/>secret/kiops/oidc"]
    end

    subgraph "Consumer Modules"
        OIDC_CM["ConfigMap<br/>label: kuberse.net/authentik-oidc=true<br/>(ArgoCD, Grafana, Kiops...)"]
    end

    VMAIN -->|"VSO syncs<br/>(pgdb + cbdb labels<br/>scoped to PG_CONNECTION_STRING)"| US
    KC -->|"admin_password<br/>admin_email"| SERVER
    US -->|"SECRET_KEY<br/>BOOTSTRAP_TOKEN<br/>PG password"| SERVER
    US -->|"SECRET_KEY<br/>BOOTSTRAP_TOKEN<br/>PG password"| WORKER

    INIT -->|"waits for"| US
    INIT -->|"then starts"| SERVER

    SERVER --> REDIS
    WORKER --> REDIS
    SERVER --- SVC --- ING

    BP -->|"auto-applied<br/>on startup"| SERVER
    JOB -->|"discovers"| OIDC_CM
    JOB -->|"creates providers/apps"| SERVER
    JOB -->|"writes clientID/clientSecret"| VO
```

## Resources Created

| Resource | Name | Description |
|----------|------|-------------|
| Deployment | `authentik-server` | Django server with init container |
| Deployment | `authentik-worker` | Celery worker with init container |
| Deployment | `authentik-redis` | Redis 7 cache/broker |
| Service | `authentik-server` | ClusterIP on ports 9000 (HTTP) and 9443 (HTTPS) |
| Service | `authentik-redis` | ClusterIP on port 6379 |
| Ingress | `authentik` | Routes `auth.kuberse.net` to port 9000 |
| ServiceAccount | `authentik-sa` | Single SA for all Authentik resources |
| ConfigMap | `authentik-blueprints` | YAML blueprints auto-applied on startup (groups, scope mappings) |
| ConfigMap | `authentik-oidc-provisioner-script` | Embeds `provision-oidc.py` |
| Job | `authentik-oidc-provisioner` | ArgoCD PostSync hook -- creates OIDC providers and writes creds to Vault |
| VaultConnection | `vault-connection` | Connection to Vault server |
| VaultAuth | `authentik-auth` | Kubernetes auth with `authentik-role` |
| VaultStaticSecret | `authentik-vault` | Syncs `secret/authentik/main` to `authentik-secrets` (dual-labeled `pgdb` + `cbdb`, both pointing to the `PG_CONNECTION_STRING` key) |
| ConfigMap | `authentik-vault-role` | Labeled `vault: setup-creds` for Vault CronJob discovery |

## Credential Sources

Authentik requires credentials from **two sources**:

### 1. Shared `kuberse-config` Secret

Created during the platform setup (CLI `kuberse setup`), this shared secret provides bootstrap credentials:

| Key | Environment Variable | Description |
|-----|---------------------|-------------|
| `admin_password` | `AUTHENTIK_BOOTSTRAP_PASSWORD` | Admin user password |
| `admin_email` | `AUTHENTIK_BOOTSTRAP_EMAIL` | Admin user email |

These values are set by the operator during the initial `kuberse setup` flow. Authentik uses them to create the initial admin user on first boot.

### 2. Vault: `secret/authentik/main`

Synced to a single K8s Secret `authentik-secrets` with dual labels (`pgdb` + `cbdb`) scoped to the `PG_CONNECTION_STRING` key:

| Key | Environment Variable | Description |
|-----|---------------------|-------------|
| `AUTHENTIK_SECRET_KEY` | `AUTHENTIK_SECRET_KEY` | Django signing key (50+ chars). **Interactive** seed (via `secrets-expected.json`). |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | `AUTHENTIK_BOOTSTRAP_TOKEN` | API token used by the OIDC provisioner Job. **Interactive** seed. |
| `PG_CONNECTION_STRING` | (used by provisioners + wait-for-db) | `postgresql://authentik:pass@postgres.platform:5432/authentik`. Seeded **automatically** by `kuberse setup`. |
| `AUTHENTIK_POSTGRESQL__PASSWORD` | `AUTHENTIK_POSTGRESQL__PASSWORD` | PostgreSQL password for Authentik. Seeded automatically. |

The `pgdb` label triggers automatic database creation via the PostgreSQL provisioner CronJob. The `cbdb` label triggers automatic connection registration in CloudBeaver. Both labels point to `PG_CONNECTION_STRING`, so the other keys stay invisible to the provisioners.

## Startup Sequence

```mermaid
sequenceDiagram
    participant Vault as Vault
    participant VSO as VSO
    participant DS as K8s Secret<br/>authentik-secrets
    participant Init as Init Container<br/>wait-for-db
    participant Server as Authentik Server
    participant BP as Blueprints
    participant Job as OIDC Provisioner Job

    VSO->>Vault: Read secret/authentik/main
    VSO->>DS: Create authentik-secrets

    Init->>Init: psql SELECT 1 against PG_CONNECTION_STRING
    Note over Init: kubelet blocks pod start until secret exists;<br/>container then polls DB every 5s
    Init->>Server: DB reachable, exit 0

    Server->>Server: Start Django + apply blueprints
    BP->>Server: Create groups (admin, developer)<br/>Create groups scope mapping

    Note over Job: ArgoCD PostSync hook
    Job->>Job: Patch CoreDNS for DNS hairpin
    Job->>Server: Wait for Authentik to be ready
    Job->>Job: Discover ConfigMaps labeled<br/>kuberse.net/authentik-oidc=true
    Job->>Server: Create OAuth2 providers + applications
    Job->>Vault: Write clientID/clientSecret to each module's Vault path
```

## Blueprints

Authentik auto-applies YAML blueprints from `/blueprints/custom/` on startup. The chart mounts a ConfigMap with a blueprint that creates:

| Resource | Name | Purpose |
|----------|------|---------|
| Group | `admin` | Admin group (not superuser) |
| Group | `developer` | Developer group |
| Scope Mapping | `groups` | Returns group names in the `groups` JWT claim |

OIDC providers and applications are **not** managed by blueprints -- they are handled by the OIDC Provisioner Job instead.

### OIDC Provisioner Job timing

The OIDC Provisioner is an ArgoCD **PostSync hook** -- it runs after every successful sync of the Authentik Application. Key behaviors:

- **First deployment**: runs once Authentik pods are healthy
- **New OIDC client added**: if another module adds a ConfigMap labeled `kuberse.net/authentik-oidc=true`, the provisioner will pick it up on the next Authentik sync (ArgoCD auto-syncs periodically, or you can force it)
- **Manual re-trigger**: delete the completed Job and sync the Authentik app: `kubectl delete job authentik-oidc-provisioner -n platform` then trigger ArgoCD sync
- **DNS hairpin side-effect**: this Job also patches CoreDNS to resolve `auth.kuberse.net` to the NGINX Ingress ClusterIP. If CoreDNS is ever reset, re-sync Authentik to restore it.

### Database startup race

Authentik's database (`authentik` in PostgreSQL) is created by the PostgreSQL provisioner CronJob (up to 5 min delay). Authentik will **crash-loop** until the database exists. This is expected behavior:

1. Authentik starts, tries to connect, fails (`database "authentik" does not exist`)
2. Kubernetes restarts the pod (CrashLoopBackOff)
3. Within 5 minutes, the PostgreSQL provisioner creates the database
4. Next restart succeeds, Authentik initializes its schema via Django migrations

No manual intervention is needed. The CrashLoopBackOff resolves automatically.

## Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| `image.tag` | `latest` | Authentik version |
| `server.replicas` | `1` | Server replicas |
| `worker.replicas` | `1` | Worker replicas |
| `service.httpPort` | `9000` | HTTP port |
| `service.httpsPort` | `9443` | HTTPS port |
| `ingress.host` | `auth.kuberse.net` | Public hostname |
| `postgresql.host` | `postgres.platform.svc.cluster.local` | PostgreSQL host |
| `postgresql.name` | `authentik` | Database name |
| `vault.secretPath` | `authentik/main` | Single Vault path for all Authentik secrets |
| `oidcProvisioner.discoveryLabel` | `kuberse.net/authentik-oidc` | Label used to discover OIDC ConfigMaps |

## Debugging

```bash
# Check Authentik pods
kubectl get pods -n platform -l app.kubernetes.io/name=authentik

# Server logs
kubectl logs -f deploy/authentik-server -n platform

# Worker logs
kubectl logs -f deploy/authentik-worker -n platform

# Init container logs (if stuck in Init)
kubectl logs deploy/authentik-server -n platform -c wait-for-db

# OIDC provisioner Job logs
kubectl logs job/authentik-oidc-provisioner -n platform

# Check if secrets exist
kubectl get secret authentik-secrets kuberse-config -n platform

# Check VaultStaticSecret sync status
kubectl describe vaultstaticsecret authentik-vault -n platform

# Verify Authentik is healthy
kubectl exec -it deploy/authentik-server -n platform -- ak healthcheck
```

### Common Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Pod stuck in `Init:0/1` | `authentik-secrets` doesn't exist | Check Vault sync: `kubectl describe vaultstaticsecret authentik-vault -n platform` |
| OIDC provisioner fails | Authentik not ready or token invalid | Check logs: `kubectl logs job/authentik-oidc-provisioner -n platform` |
| "Connection refused" from OIDC clients | DNS hairpin not configured | Check CoreDNS: `kubectl get cm coredns -n kube-system -o yaml` |
| OIDC login redirects to Cloudflare Access | DNS hairpin missing/stale IP | Re-run provisioner or check ingress controller ClusterIP |
