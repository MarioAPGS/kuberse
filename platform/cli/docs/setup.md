# Platform Setup

## Overview

Kuberse is a self-bootstrapping Kubernetes platform that deploys a full GitOps-managed environment (ArgoCD, Vault, PostgreSQL, SSO, ingress, and more) with a single command. The end result is a production-ready cluster where every component is declaratively managed and secrets are handled through HashiCorp Vault.

The bootstrap runs in two stages:

1. **`kuberse init`** — Runs on your local machine (laptop/workstation). Creates or connects to a Kubernetes cluster, deploys a privileged CLI pod, and hands off control to the in-cluster environment.
2. **`kuberse setup`** — Runs automatically inside the CLI pod. Performs the full platform bootstrap: configures Git, deploys Vault, seeds secrets, installs ArgoCD, and wires up GitOps for the entire platform.

The CLI pod runs inside the cluster (rather than from your laptop) to ensure a consistent environment and direct network access to in-cluster services like Gitea, Vault, and the Kubernetes API.

The entire process takes a single `kuberse init` invocation from your terminal — the transition between stages is seamless.

---

## Prerequisites

### On your host machine

- `kubectl` installed
- The `kuberse` CLI installed (Python package)
- **Minikube mode:** Docker and `minikube` installed
- **k3s mode:** `ssh` and `scp` available

### For k3s mode — VM requirements

- Debian or Ubuntu VMs (minimum: 2 CPU, 4 GB RAM, 40 GB disk per node)
- SSH reachable from your laptop with public key authentication
- SSH user with **passwordless sudo** (`sudo` without password prompt)
- `curl` available on all nodes (for the k3s installer)
- Port 6443/TCP open between nodes and from your host to the server

### Minimum cluster resources

The full platform (Vault, ArgoCD, Postgres, Authentik, ingress-nginx, etc.) needs approximately:
- **Minikube:** at least 8 GB RAM and 4 CPUs allocated
- **k3s:** at least 2 nodes with 4 GB RAM each (or a single node with 8 GB)

---

## Cluster Modes

| Mode | Use case | Infrastructure |
|------|----------|----------------|
| **minikube** | Local development | Docker on your machine |
| **k3s** | Staging / production-like | Remote Debian/Ubuntu VMs via SSH |

---

## Phase 1: `kuberse init` (on your machine)

### Step 1.1 — Configuration prompts

The CLI asks you for all the information it needs upfront:

| Prompt | Description | Example |
|--------|-------------|---------|
| Cluster mode | `minikube` or `k3s` | `1` |
| Git provider | `github` or `gitea` (in-cluster). GitHub is simpler for development; Gitea gives you a fully airgapped, self-contained deployment. | `2` |
| Base domain | Domain suffix for all platform services | `kuberse.local` |
| Admin email | Used for SSO (Authentik — the platform's identity provider) and certificates | `admin@company.com` |
| Admin password | Single password shared across ArgoCD, Postgres, Authentik | `••••••••` |
| GitHub org + PAT | *(GitHub mode only)* Organization and personal access token (scopes: `repo`, `read:packages`) | `myorg` |
| k3s server host | *(k3s mode only)* IP/hostname of the control-plane VM | `192.168.1.10` |
| k3s worker hosts | *(k3s mode only)* IPs of worker nodes (blank to finish) | `192.168.1.11` |
| SSH user | *(k3s mode only)* SSH username on all nodes | `debian` |
| SSH key path | *(k3s mode only)* Path to private key | `~/.ssh/id_ed25519` |
| k3s version | *(k3s mode only)* Version to install | `v1.31.4+k3s1` |

The SSH key path is validated immediately — if the file doesn't exist, the CLI exits with a helpful `ssh-keygen` suggestion. The password prompt requires double-entry confirmation.

All answers are frozen into an immutable configuration object used throughout the rest of the process.

### Step 1.2 — Cluster provisioning

#### Minikube mode

| Phase | What happens |
|-------|--------------|
| Delete existing cluster | `minikube delete` (safe if nothing exists) |
| Start fresh cluster | `minikube start --driver=docker --cpus=max --memory=max --insecure-registry=10.0.0.0/8` |
| Wait for kube-system | Polls until all system pods are Running + Ready (300s timeout) |
| Enable metrics | `minikube addons enable metrics-server` |

The `--insecure-registry=10.0.0.0/8` flag allows pulling from the in-cluster Gitea OCI registry without TLS — essential for Gitea mode.

#### k3s mode

| Phase | What happens |
|-------|--------------|
| Clean previous installs | SSH to all nodes, run `k3s-uninstall.sh` and `k3s-agent-uninstall.sh` (best-effort, no failure if absent) |
| Install k3s server | SSH to server node, runs the official installer with `--disable=traefik --disable=servicelb` |
| Capture join token | Reads the join token from the server (k3s uses this token to authorize worker nodes joining the cluster) |
| Join worker nodes | SSH to each worker, runs the k3s agent installer pointing at the server |
| Fetch kubeconfig | `scp` the kubeconfig from the server to `~/.kube/config-kuberse` |
| Rewrite kubeconfig | Replaces `127.0.0.1` with the actual server host, renames the context from `default` to `kuberse` |
| Set KUBECONFIG | Exports the variable so all subsequent `kubectl` calls target this cluster |
| Wait for kube-system | Polls until all system pods are Running + Ready (300s timeout) |
| Install metrics-server | Applies the upstream metrics-server manifest and patches `--kubelet-insecure-tls` (needed for k3s self-signed certs) |

Traefik and ServiceLB are disabled because Kuberse deploys its own ingress stack (ingress-nginx) and optionally Cloudflare Tunnel via the networking plugin.

The kubeconfig is written to `~/.kube/config-kuberse` (mode `0600`) and **never** touches your existing `~/.kube/config`. After `kuberse init` finishes, you need to export it manually for subsequent terminal sessions:

```bash
export KUBECONFIG=$HOME/.kube/config-kuberse
```

### Step 1.3 — Deploy the CLI pod

This step is identical for both cluster modes — it only requires a working Kubernetes API:

1. **Create `platform` namespace** — idempotent (no error if it exists)
2. **Create `Secret/kuberse-config`** — stores all configuration values as flat key-value pairs mounted into the pod at `/etc/kuberse/`
3. **Create `ServiceAccount/kuberse-cli`** + `ClusterRoleBinding` — grants `cluster-admin` so the pod can install CRDs, create namespaces, etc.
4. **Deploy `Pod/kuberse-cli`** — runs the `ghcr.io/marioapgs/kuberse/img/kuberse-cli:latest` image with:
   - `/etc/kuberse/` mounted read-only (configuration)
   - `/workspace/` as an `emptyDir` (working space for git clones)
   - Resource limits: 512Mi memory, 500m CPU
5. **Wait for Ready** — 120s timeout for the pod to pull the image and start

> **Important:** The CLI pod image is always pulled from `ghcr.io` at this stage, even in Gitea mode. The nodes must have internet access to GHCR during initial bootstrap.

### Step 1.4 — Handoff to the pod

The CLI replaces its own process with:

```bash
kubectl exec -it kuberse-cli -n platform -- bash -c "kuberse setup; exec bash"
```

From this point, your terminal is inside the cluster. `kuberse setup` runs automatically. If it finishes (success or error), you're left in a bash shell inside the pod for inspection.

---

## Phase 2: `kuberse setup` (inside the cluster)

All phases run strictly in sequence. Each phase is wrapped in error handling that prints a clear message on failure. The entire flow is **idempotent** — re-running after a failure picks up where it left off.

### Step 2.1 — Provider setup

- **GitHub:** No action. GitHub is already reachable from the cluster.
- **Gitea:** Installs Gitea into the cluster using the platform umbrella chart (a single Helm chart containing all platform subcharts, each toggleable via an `enabled` flag) with only the `gitea` subchart enabled. Waits until the Gitea API responds (120s). This gives the platform its own in-cluster Git server and OCI registry.

### Step 2.2 — Fork the registry repo

The "registry repo" is the Git repository that ArgoCD watches — it contains all Application manifests that define what's deployed in the cluster.

- **GitHub:** Forks `MarioAPGS/kuberse` into your GitHub organization. Polls until the fork is ready (up to 60s).
- **Gitea:** Creates the `kuberse` organization in Gitea and mirrors the upstream repo via `POST /api/v1/repos/migrate`.

### Step 2.3 — Clone the registry

Clones the forked/mirrored repository to `/workspace/registry` inside the pod. This is the working copy where all modifications happen.

### Step 2.4 — Resolve placeholders

Walks every file in the cloned repo (skipping `.git/`) and performs string substitution:

| Placeholder | Replaced with |
|-------------|---------------|
| `${REGISTRY_URL}` | OCI registry URL (e.g. `ghcr.io/myorg` or `gitea-http.platform.svc.cluster.local:3000/kuberse`) |
| `${GIT_BASE_URL}` | Git server URL (e.g. `https://github.com` or `http://gitea-http.platform.svc.cluster.local:3000`) |
| `${ORG_NAME}` | Organization name (e.g. `myorg` or `kuberse`) |
| `${BASE_DOMAIN}` | Your chosen base domain |
| `${ADMIN_EMAIL}` | Admin email address |
| `${ADMIN_USERNAME}` | Derived from the email (part before `@`) |
| `${ADMIN_PASSWORD}` | Admin password |
| `${GIT_PROVIDER}` | `github` or `gitea` |
| `${CLUSTER_MODE}` | `minikube` or `k3s` |
| `${GIT_BASE_URL_EXTERNAL}` | External Git URL (may differ from internal for Gitea) |

After this step, all Application manifests contain concrete values instead of template tokens.

### Step 2.5 — Mirror artifacts (Gitea only)

In Gitea mode, the platform must be fully self-contained. This phase copies all required artifacts from `ghcr.io` into the in-cluster Gitea OCI registry:

**Charts mirrored:**
- `platform` (the main umbrella chart)
- `runners`
- `buildapp`

**Images mirrored:** 7 container images (kuberse-cli, kuberse-api, kiops, dev-kit, kuberse-runner, etc.)

The mirror uses `oras copy` (ORAS — OCI Registry As Storage, a CLI tool for copying OCI artifacts between registries) with `--to-plain-http` for the internal registry. After mirroring, chart version placeholders (`${PLATFORM_VERSION}`, `${RUNNERS_VERSION}`, `${BUILDAPP_VERSION}`) are resolved with the actual versions discovered during the copy.

### Step 2.6 — Push configuration

Commits all changes and pushes to the registry repo:

```
git add -A
git commit -m "feat: configure kuberse instance"
git push origin main
```

At this point, the registry repo is fully configured but nothing is deployed yet.

### Step 2.7 — Deploy Vault

Vault is deployed **before** ArgoCD to eliminate race conditions (see [Why Vault is deployed first](#why-vault-is-deployed-first) below).

The CLI:

1. Pulls the `platform` umbrella chart from the OCI registry via `oras`
2. Renders it with `helm template` enabling only the `vault` and `vault-secrets-operator` subcharts
3. Applies the rendered manifests with `kubectl apply --server-side --force-conflicts`
4. Waits for all Vault pods to reach Ready state (300s)

> **Why not `helm install`?** The CLI uses `oras pull` + `helm template` + `kubectl apply --server-side` instead of a normal `helm install` because: (a) `helm pull` has issues resolving tags against some OCI registries (notably Gitea), while `oras` works uniformly; (b) server-side apply allows ArgoCD to later adopt the resources without field ownership conflicts.

This deploys:
- Vault HA StatefulSet (Raft storage)
- Vault Secrets Operator (VSO) — watches `VaultStaticSecret` CRDs
- `VaultConnection` and `VaultAuth` resources for VSO
- `vault-module-config` CronJob (provisions per-module policies every 5 minutes)
- Vault Ingress for UI access

### Step 2.8 — Initialize and unseal Vault

| Sub-step | What happens |
|----------|--------------|
| Check initialized | `vault status` — if already initialized, reads keys from existing `Secret/vault-init-keys` |
| Initialize | `vault operator init` with 5 key shares, threshold 3. Stores root token + all unseal keys in `Secret/vault-init-keys` |

> **Security note:** The unseal keys and root token are stored in a Kubernetes Secret within the same cluster. This is acceptable for development and single-team staging environments. For production, consider migrating unseal keys to an external KMS or secure storage.
| Unseal all pods | Loops through every Vault pod, applies 3 unseal keys to each sealed pod |
| Enable KV engines | `vault secrets enable kv-v2` at paths `secret/` and `buildapps/` |
| Enable K8s auth | `vault auth enable kubernetes` |
| Create VSO policy | Grants read access on `secret/data/*` and `buildapps/data/*` |
| Create VSO role | Binds the `vault-secrets-operator-controller-manager` ServiceAccount to the policy |

Every sub-step is idempotent:
- Init is skipped if already initialized
- Unseal is skipped per-pod if already unsealed
- `secrets enable` / `auth enable` tolerate "already enabled" responses
- Policy and role writes are upserts

### Step 2.9 — Seed Vault secrets

Writes the initial secrets that platform components need on first boot:

| Vault path | Keys | Used by |
|------------|------|---------|
| `secret/postgres/config` | `POSTGRES_USER`, `POSTGRES_PASSWORD` | PostgreSQL chart |
| `secret/authentik/config` | `AUTHENTIK_BOOTSTRAP_EMAIL`, `AUTHENTIK_BOOTSTRAP_PASSWORD` | Authentik chart |

Both use the same credentials from your init prompts:
- `POSTGRES_USER` = admin username (derived from email)
- `POSTGRES_PASSWORD` = `AUTHENTIK_BOOTSTRAP_PASSWORD` = the admin password you chose

Values are sent via stdin as JSON to avoid shell metacharacter issues with special characters in passwords.

After this step, every `VaultStaticSecret` resource deployed by ArgoCD will resolve immediately — no waiting, no retries.

### Step 2.10 — Install ArgoCD

1. **Pre-seed admin password** — creates `Secret/argocd-secret` with `admin.password` set to the bcrypt hash of your admin password. This means ArgoCD uses your chosen password from the start (no random generated password).
2. **Apply upstream install.yaml** — `kubectl apply --server-side` of the official ArgoCD manifests.
3. **Wait for ArgoCD** — waits for `argocd-server` and all ArgoCD deployments to become Available (300s).

ArgoCD is installed directly (not via GitOps) because it cannot manage its own initial deployment — a chicken-and-egg problem. Once running, ArgoCD will adopt and manage itself going forward.

### Step 2.11 — Configure ArgoCD credentials

Creates Secrets in the `argocd` namespace so ArgoCD can access your Git provider and OCI registry:

**GitHub mode:**
- `github-repo-creds` — Git credentials for cloning the registry repo
- `github-registry-secret` — Docker config JSON for pulling from `ghcr.io`, replicated to all namespaces via `kubernetes-replicator` (a controller that copies annotated Secrets across namespaces)

**Gitea mode:**
- `gitea-repo-creds` — Git credentials for the internal Gitea URL
- `gitea-oci-creds` — OCI Helm repo credentials with `enableOCI`, `insecure`, and `insecureOCIForceHttp` flags (required because the in-cluster registry is plain HTTP)
- `github-registry-secret` — Docker config JSON with both Gitea and `ghcr.io` keys, replicated to all namespaces

### Step 2.12 — Deploy the bootstrap Application

Applies `bootstrap.yaml` — a single ArgoCD Application that recursively scans the `argocd/` directory in your registry repo. This triggers the app-of-apps cascade:

```
bootstrap.yaml
  └── argocd/platform/argocd-app-of-apps.yaml
        ├── argocd/platform/vault/argocd-app.yaml        (adopts existing Vault)
        ├── argocd/platform/postgres/argocd-app.yaml     (new deploy)
        ├── argocd/platform/authentik/argocd-app.yaml    (new deploy)
        ├── argocd/platform/ingress-nginx/argocd-app.yaml
        └── ... (all other platform components)
  └── argocd/runners/argocd-app-of-apps.yaml
  └── argocd/plugins/<name>/argocd-app-of-apps.yaml
```

**Vault adoption:** Since Vault was already deployed by the CLI (step 2.7), ArgoCD discovers the existing resources and adopts them via server-side apply — no drift, no redeploy. The Vault Application still exists in the registry repo for ongoing management.

ArgoCD deploys components respecting sync waves:
- Wave -1: Namespaces
- Wave 0: App-of-apps, kubernetes-replicator
- Wave 1: All platform components (vault, ingress-nginx, postgres, authentik, etc.)
- Wave 2: Plugins, runners

### Step 2.13 — Trigger module-config Job

The `vault-module-config` CronJob runs every 5 minutes to create Vault policies and auth roles for each platform module. To avoid a 5-minute wait on first boot:

1. Waits for the CronJob resource to exist (just deployed by ArgoCD)
2. Waits for at least one `ConfigMap` with label `vault=setup-creds` to appear (proves consumer charts are being deployed)
3. Creates a one-shot Job from the CronJob template: `kubectl create job vault-module-config-init --from=cronjob/vault-module-config`
4. Waits for the Job to complete (180s)

After this, every module's `VaultAuth` can mint tokens and every `VaultStaticSecret` syncs successfully.

### Step 2.14 — Summary

The CLI prints a final panel:

```
Kuberse platform is ready!

Credentials (all services):
  Username: <admin_username>
  Password: <admin_password>

Services using these credentials:
  - ArgoCD UI (admin)
  - PostgreSQL (superuser)
  - Authentik (bootstrap admin)

Monitor deployment:
  kubectl get applications -n argocd
  kubectl get pods -n platform
```

---

## Why Vault is Deployed First

In the previous architecture, ArgoCD deployed Vault simultaneously with its consumers:

```
ArgoCD starts → deploys Vault + Postgres + Authentik in parallel
                → Postgres needs secrets from Vault
                → Vault isn't initialized yet
                → Postgres crash-loops for 3-5 minutes
```

The current architecture eliminates this entirely:

```
CLI deploys Vault → CLI initializes + seeds secrets → CLI installs ArgoCD
→ ArgoCD starts → consumers find secrets ready on first sync → everything green
```

Benefits:
- **No race conditions** — secrets exist before any consumer starts
- **Green from the start** — no crash-loops, no Degraded applications
- **Predictable credentials** — one password for everything, set during init
- **Fast module policies** — created in seconds via triggered Job, not waiting for the CronJob schedule

---

## DNS Requirements

After bootstrap, platform services are available at `<service>.<base_domain>`. DNS setup depends on your environment:

| Setup | DNS configuration |
|-------|-------------------|
| Minikube + `*.local` domain | Add entries to `/etc/hosts` pointing to `$(minikube ip)`, or use `minikube tunnel` with `127.0.0.1` |
| k3s + real domain | Configure wildcard DNS (`*.<base_domain>`) pointing to your server node IP |
| k3s + Cloudflare Tunnel (networking plugin) | DNS is managed automatically by the tunnel |

---

## Idempotency and Re-runs

Every phase in both `kuberse init` and `kuberse setup` is designed to be re-runnable:

| Phase | Idempotency mechanism |
|-------|-----------------------|
| Cluster provisioning | Deletes first, then creates fresh (**warning:** re-running `kuberse init` destroys your existing cluster and all data) |
| Pod deployment | `kubectl apply` is upsert |
| Vault deploy | `kubectl apply --server-side` is upsert |
| Vault init/unseal | Checks status before acting |
| Vault secrets | `vault kv put` is upsert |
| ArgoCD install | `kubectl apply --server-side` is upsert |
| Bootstrap deploy | `kubectl apply` is upsert |
| Module-config Job | Skipped if Job already exists |

If something fails, re-run `kuberse setup` from inside the pod:

```bash
# Re-enter the pod
kuberse cli

# Re-run setup
kuberse setup
```

Or start completely fresh from your host:

```bash
kuberse init
```

---

## Troubleshooting

### CLI pod doesn't start

The pod image is pulled from `ghcr.io`. Verify your cluster nodes can reach it:

```bash
kubectl describe pod kuberse-cli -n platform
# Look for image pull errors in Events
```

### k3s: `wait for kube-system` hangs

- Check port 6443/TCP is open from your host to the server
- Verify the server host you entered matches the certificate SANs (k3s signs certs for detected local IPs)
- If you used a FQDN, add `--tls-san <your-fqdn>` to the k3s server extra args

### Setup fails at "Provider setup" (Gitea)

Gitea installation may fail if the cluster doesn't have enough resources. Check:

```bash
kubectl get pods -n platform -l app.kubernetes.io/name=gitea
kubectl describe pod <gitea-pod> -n platform
```

### ArgoCD shows Degraded apps after bootstrap

Usually transient — the vault-module-config Job may still be running. Wait 2-3 minutes, then:

```bash
kubectl get applications -n argocd
```

If it persists, trigger the module-config Job manually:

```bash
kubectl -n platform create job vault-module-config-manual --from=cronjob/vault-module-config
```

### After init: kubectl doesn't work

For k3s mode, the KUBECONFIG variable only lived in the `kuberse init` process. Export it:

```bash
export KUBECONFIG=$HOME/.kube/config-kuberse
kubectl get nodes
```

---

## What Gets Deployed

After a successful bootstrap, your cluster contains:

| Namespace | Services | URLs |
|-----------|----------|------|
| `platform` | Vault, PostgreSQL, Authentik, Gitea (if Gitea mode), ingress-nginx, kuberse-api, kuberse-cli, cloudbeaver, kubrain | `vault.<domain>`, `auth.<domain>`, `gitea.<domain>`, `cloudbeaver.<domain>`, `kubrain.<domain>` |
| `argocd` | ArgoCD (server, repo-server, controller, redis) | `argocd.<domain>` |
| `networking` | *(if networking plugin installed)* Cloudflare Tunnel | — |
| `observability` | *(if observability plugin installed)* Grafana, Loki, Prometheus | `grafana.<domain>` |

All services share the same admin credentials you set during `kuberse init`.

---

## Teardown

**Minikube mode:**

```bash
minikube delete
```

**k3s mode:**

```bash
# From your host, SSH to each node:
ssh <user>@<server> 'sudo /usr/local/bin/k3s-uninstall.sh'
ssh <user>@<worker> 'sudo /usr/local/bin/k3s-agent-uninstall.sh'

# Remove the kubeconfig:
rm ~/.kube/config-kuberse
```

Alternatively, re-running `kuberse init` will automatically uninstall k3s on all nodes before reinstalling.
