# Placeholder System

## Overview

Every YAML file in this repository is a **template**. Before the platform can run, placeholders must be resolved with your specific configuration. The `kuberse setup` command handles this automatically.

## How It Works

During `kuberse setup`, the CLI:

1. Clones/forks this repo
2. Walks every file (excluding `.git/` and `docs/`)
3. Replaces all `${PLACEHOLDER}` tokens with values from your configuration
4. Commits the resolved files
5. Pushes to your fork

After resolution, ArgoCD reads plain YAML — no templating engine runs at deploy time.

> **Note:** The `detect_unresolved` check also skips `.github/` in addition to `.git/` and `docs/`.

## Available Placeholders

| Placeholder | Description | Example value |
|-------------|-------------|---------------|
| `${BASE_DOMAIN}` | Your platform domain | `mycompany.dev` |
| `${ORG_NAME}` | GitHub org or Gitea org | `my-org` |
| `${REGISTRY_URL}` | OCI registry host | `ghcr.io` or `gitea.internal:3000` |
| `${GIT_BASE_URL}` | Git server base URL | `https://github.com` |
| `${ADMIN_EMAIL}` | Platform admin email | `admin@mycompany.dev` |
| `${ADMIN_USERNAME}` | Derived from email | `admin` |
| `${GIT_PROVIDER}` | `github` or `gitea` | `github` |
| `${CLUSTER_MODE}` | `minikube` or `k3s` | `k3s` |
| `${PLATFORM_VERSION}` | Platform chart version (auto-resolved) | `1.4.2` |
| `${KUBERSE_<PLUGIN>_VERSION}` | Plugin chart version (auto-resolved) | `0.3.1` |

## Where Placeholders Appear

Placeholders are used in ArgoCD Application manifests:

```yaml
# Before resolution (template)
spec:
  source:
    repoURL: ${REGISTRY_URL}/${ORG_NAME}/charts/platform
    targetRevision: ${PLATFORM_VERSION}
  destination:
    namespace: platform

# After resolution (your fork)
spec:
  source:
    repoURL: ghcr.io/my-org/charts/platform
    targetRevision: 1.4.2
  destination:
    namespace: platform
```

They also appear in:
- Ingress host annotations (`app.${BASE_DOMAIN}`)
- Authentik OIDC configurations
- Vault secret paths
- Backstage catalog entities

## Configuration Sources

The CLI collects placeholder values from multiple sources (in priority order):

1. **Interactive prompts** during `kuberse setup` (domain, email, provider)
2. **Auto-detection** (cluster mode, registry capabilities)
3. **Computed values** (chart versions after OCI mirror, username from email)
4. **Config file** (`~/.config/kuberse/config.yaml` for repeat runs)

## Plugin Placeholders

When you install a plugin, its manifests also contain placeholders. The CLI resolves them using the same configuration plus plugin-specific values:

```bash
kuberse plugin install kuberse-networking
# Resolves: ${KUBERSE_NETWORKING_VERSION} → 0.2.5
# Plus all standard placeholders
```

## Updating After Upstream Changes

When the upstream registry adds new features or services:

```bash
kuberse update
```

This syncs your fork with upstream, resolves any new placeholders in added files, and commits. ArgoCD then deploys the new services.

## Custom Values

If you need to override Helm values beyond what placeholders provide, edit the `helm.values` block in the relevant `argocd-app.yaml`:

```yaml
spec:
  source:
    helm:
      values: |
        vault:
          enabled: true
          server:
            resources:
              requests:
                memory: 512Mi  # Your custom override
```

These overrides persist across `kuberse update` because the CLI only resolves `${...}` tokens — it does not modify other content.
