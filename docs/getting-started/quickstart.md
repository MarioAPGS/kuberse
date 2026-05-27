# Quick Start

Deploy the full Kuberse platform from zero to running in under 15 minutes.

## Prerequisites

| Requirement | Minimum | Purpose |
|-------------|---------|---------|
| Docker or Podman | Docker 24+ | Container runtime for cluster |
| kubectl | 1.28+ | Cluster interaction |
| helm | 3.14+ | Chart management |
| oras | 1.1+ | OCI artifact operations |
| gh (GitHub mode) | 2.40+ | Fork, clone, push |
| RAM | 8 GB free | Platform services need resources |
| Disk | 20 GB free | Images and volumes |

## Step 1: Fork the Registry

```bash
# GitHub mode
gh repo fork kuberse/kuberse-registry --org=my-org --clone=false
```

This creates your personal copy of the platform template. All your configuration will live here.

## Step 2: Initialize the Cluster

```bash
kuberse init
```

Interactive prompts will guide you through configuration (provider, cluster mode, etc.).

This command:
- Creates a local Kubernetes cluster (Minikube or k3s)
- Deploys the CLI pod with all tools pre-installed
- Opens a shell inside the pod

> **Note:** For production, use `--cluster-mode=k3s` with remote nodes. See [K3s Setup](../platform/overview.md) for multi-node deployment.

## Step 3: Run Setup

Inside the CLI pod:

```bash
kuberse setup
```

This runs all setup steps in order. You can also run individual steps:

```bash
kuberse setup provider    # Set up git provider only
kuberse setup vault       # Deploy Vault only
kuberse setup --force     # Re-run all steps even if previously completed
```

Each step is idempotent and tracks completion in `.kuberse-setup-state.json`. If setup fails partway through, re-running `kuberse setup` resumes from where it left off.

The interactive wizard prompts for:
- **Base domain** — e.g., `mycompany.dev` (needs DNS control)
- **Admin email** — for certificates and Authentik admin
- **Git provider** — `github` or `gitea`
- **OCI registry** — defaults to `ghcr.io` for GitHub

### What Setup Does (7 steps)

```
 1. provider    — Set up git provider (Gitea/GitHub)
 2. registry    — Clone/fork registry, resolve placeholders
 3. artifacts   — Mirror OCI charts/images to internal registry
 4. vault       — Deploy, initialize, and unseal Vault
 5. seed        — Seed Vault with required secrets
 6. argocd      — Deploy and configure ArgoCD
 7. bootstrap   — Apply bootstrap.yaml, wait for services
```

## Step 4: Verify

After setup completes, you'll see:

```
✓ Platform deployed successfully!

Access URLs:
  ArgoCD:    https://argocd.mycompany.dev
  Vault:     https://vault.mycompany.dev
  Authentik: https://auth.mycompany.dev
  Kubrain:   https://kubrain.mycompany.dev

Admin credentials stored in Vault at: kv-v2/kuberse/admin
```

Check ArgoCD to see all applications syncing:

```bash
kubectl get applications -n argocd
```

## Step 5: Install Plugins (Optional)

```bash
# Add Cloudflare Tunnel for public access
kuberse plugin install oci://ghcr.io/marioapgs/kuberse-networking-plugin:latest

# Add monitoring stack
kuberse plugin install oci://ghcr.io/marioapgs/kuberse-observability-plugin:latest

# Add AI services
kuberse plugin install oci://ghcr.io/marioapgs/kuberse-ai-plugin:latest
```

## Local Development Mode

For local testing without a real domain:

```bash
kuberse init
kuberse setup
# Use domain: kuberse.localhost
# Access via port-forward or /etc/hosts entries
```

## Next Steps

- [Architecture](../architecture.md) — Understand how components interact
- [Platform Components](../platform/overview.md) — Deep dive into each service
- [Plugin System](../plugins/overview.md) — Extend with additional capabilities
- [CLI Reference](../cli/reference.md) — All commands and options

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Pod stuck in `ImagePullBackOff` | Check registry credentials: `kuberse secrets seed --scope=registry` |
| Vault sealed after restart | Run `kuberse secrets unseal` or check auto-unseal CronJob |
| ArgoCD shows `Unknown` | Wait 3 min for sync, or click "Refresh" in UI |
| DNS not resolving | Verify Cloudflare Tunnel is running: `kubectl get pods -n networking` |
| Setup fails at step 4 | Ensure 8GB+ RAM available; Vault needs resources |
