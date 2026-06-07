# Placeholder System

## Overview

Every YAML file in this repository is a **template**. Before the platform can run, `${PLACEHOLDER}` tokens must be resolved with your specific configuration. The `kuberse setup` command handles this automatically.

This system is the bridge between a generic upstream template and your personalized platform installation.

## How It Works

### Resolution Flow

During `kuberse setup`, the CLI:

1. Clones/forks this repo
2. Configures the `upstream` remote (pointing to `MarioAPGS/kuberse`) for future updates
3. Walks every file in the working tree, replacing all `${PLACEHOLDER}` tokens with values from your configuration
4. Commits the resolved files
5. Pushes to your fork

After resolution, ArgoCD reads plain YAML — no templating engine runs at deploy time.

### Skipped Directories

The placeholder resolver skips these directories:

| Directory | Why |
|-----------|-----|
| `.git/` | Git internals |
| `.github/` | GitHub Actions uses `${{ ... }}` syntax — different system |
| `.gitea/` | Gitea Actions uses the same `${{ ... }}` syntax |
| `docs/` | Documentation references tokens literally for explanation |

### The Resolution Engine

The engine is intentionally simple: **pure string replacement**. For each file:

```
for (placeholder, value) in replacements:
    content = content.replace(placeholder, value)
```

This means:
- It works inside YAML strings, multiline blocks, comments — anywhere
- It's idempotent — running on already-resolved files is a no-op (the tokens simply aren't found)
- Order doesn't matter — each replacement is independent

## Available Placeholders

### Standard Placeholders (from config)

These are automatically available from the `kuberse-config` K8s Secret (mounted at `/etc/kuberse/`):

| Placeholder | Description | Example value |
|-------------|-------------|---------------|
| `${BASE_DOMAIN}` | Your platform domain | `mycompany.dev` |
| `${ORG_NAME}` | GitHub org or Gitea org | `my-org` |
| `${REGISTRY_URL}` | OCI registry host (without org) | `ghcr.io` or `gitea-http.platform.svc.cluster.local:3000` |
| `${GIT_BASE_URL}` | Git server base URL (internal) | `https://github.com/my-org` or `http://gitea-http.platform.svc.cluster.local:3000` |
| `${GIT_BASE_URL_EXTERNAL}` | Git server URL (external access) | `https://github.com/my-org` |
| `${ADMIN_EMAIL}` | Platform admin email | `admin@mycompany.dev` |
| `${ADMIN_USERNAME}` | Derived from email (part before `@`) | `admin` |
| `${ADMIN_PASSWORD}` | Platform admin password | *(secret)* |
| `${GIT_PROVIDER}` | Git/registry provider | `github` or `gitea` |
| `${CLUSTER_MODE}` | Cluster deployment mode | `minikube` or `k3s` |
| `${GITHUB_TOKEN}` | GitHub PAT (GitHub mode only) | `ghp_...` |

### Computed Placeholders (auto-resolved)

| Placeholder | Description | Resolved by |
|-------------|-------------|-------------|
| `${PLATFORM_VERSION}` | Platform umbrella chart version | OCI artifact sync (Gitea mode) |
| `${KUBERSE_NETWORKING_VERSION}` | Networking plugin chart version | Plugin install/update |
| `${KUBERSE_OBSERVABILITY_VERSION}` | Observability plugin chart version | Plugin install/update |
| `${KUBERSE_AI_VERSION}` | AI plugin chart version | Plugin install/update |

The version placeholder naming convention: `${<CHART_NAME_UPPER>_VERSION}` where hyphens in the chart name become underscores (e.g., `kuberse-networking` → `KUBERSE_NETWORKING_VERSION`).

### Custom Placeholders (plugin-defined)

Plugins can declare custom placeholders in their `plugin.yaml` under `spec.placeholders`. If the value isn't already in the config, the CLI prompts the user during install and **persists the value** to the `kuberse-config` Secret for future use.

## Configuration Source

All placeholder values originate from the Kubernetes Secret `kuberse-config` in the `platform` namespace:

```
Secret/kuberse-config (namespace: platform)
    ↓ mounted as volume
/etc/kuberse/  (one file per key)
    ├── base_domain        → ${BASE_DOMAIN}
    ├── org_name           → ${ORG_NAME}
    ├── registry_url       → ${REGISTRY_URL}
    ├── git_base_url       → ${GIT_BASE_URL}
    ├── admin_email        → ${ADMIN_EMAIL}
    ├── admin_password     → ${ADMIN_PASSWORD}
    ├── git_provider       → ${GIT_PROVIDER}
    ├── cluster_mode       → ${CLUSTER_MODE}
    └── ...                → ${FILENAME_UPPERCASED}
```

**Dynamic discovery:** The CLI reads ALL files in `/etc/kuberse/`, maps each `filename.upper()` to a placeholder key. Adding a new key to the Secret automatically makes it available as `${KEY}` — no code changes needed.

## Where Placeholders Appear

### ArgoCD Application manifests (OCI chart sources)

```yaml
# Before resolution (template in upstream)
spec:
  source:
    repoURL: oci://${REGISTRY_URL}/${ORG_NAME}/kuberse/helm/platform
    chart: platform
    targetRevision: ${PLATFORM_VERSION}
  destination:
    namespace: platform

# After resolution (your fork)
spec:
  source:
    repoURL: oci://ghcr.io/my-org/kuberse/helm/platform
    chart: platform
    targetRevision: 1.4.2
  destination:
    namespace: platform
```

### ArgoCD Application manifests (Git sources)

```yaml
# Before resolution
spec:
  source:
    repoURL: ${GIT_BASE_URL}/${ORG_NAME}/kuberse
    targetRevision: main
    path: plugins/kuberse-networking

# After resolution
spec:
  source:
    repoURL: https://github.com/my-org/kuberse
    targetRevision: main
    path: plugins/kuberse-networking
```

### Other locations

- Ingress host annotations: `vault.${BASE_DOMAIN}`
- Authentik OIDC configurations: `https://auth.${BASE_DOMAIN}/...`
- Backstage catalog entities: `owner: ${ORG_NAME}`
- Image repositories: `${REGISTRY_URL}/${ORG_NAME}/kuberse/img/kubrain`
- Organization configs: `email: ${ADMIN_EMAIL}`

## Plugin Placeholders

When you install a plugin, its manifests also contain placeholders. The CLI resolves them using the same configuration plus plugin-specific values:

```bash
kuberse plugin install oci://ghcr.io/marioapgs/kuberse-networking-plugin:latest
# Resolves: ${KUBERSE_NETWORKING_VERSION} → 0.2.5
# Plus all standard placeholders: ${REGISTRY_URL}, ${ORG_NAME}, ${BASE_DOMAIN}, ...
```

### Custom plugin placeholders (`spec.placeholders`)

A plugin can declare placeholders not present in the standard config:

```yaml
# In plugin.yaml
spec:
  placeholders:
    - REGISTRY_URL          # Already in config → resolved automatically
    - BASE_DOMAIN           # Already in config → resolved automatically
    - CUSTOM_WEBHOOK_URL    # NOT in config → user is prompted
```

**Behavior by case:**

| Placeholder | In config? | What happens |
|-------------|-----------|--------------|
| `REGISTRY_URL` | Yes | Resolved automatically (declaration is documentation-only) |
| `CUSTOM_WEBHOOK_URL` | No | User is prompted, value is resolved AND persisted to `kuberse-config` |

**Persistence:** Values entered by the user during plugin install are written to the `kuberse-config` K8s Secret via `kubectl patch`. On subsequent runs (reinstall, update, pod restart), the value is found automatically — no re-prompting.

## Updating After Upstream Changes

```bash
kuberse update
```

This command:

1. Fetches and merges from the `upstream` remote (pointing to `MarioAPGS/kuberse`)
2. Resolves all known placeholders on the merged result
3. If new `${...}` tokens remain (from features added upstream), prompts for their values
4. Commits and pushes

**Why this is safe:** Already-resolved files don't contain `${...}` tokens anymore, so the resolution pass is a no-op for them. New files from upstream arrive with fresh tokens that get resolved in step 2-3.

## Two Separate Systems — Don't Confuse Them

| System | Syntax | Purpose | Used by |
|--------|--------|---------|---------|
| **Placeholders** | `${FOO}` | Template personalization (URLs, domains, orgs) | `PlaceholderManager` in YAML files |
| **Vault secrets** | `{FOO}` | Interactive secret seeding (passwords, tokens) | `secrets-expected.json` for Vault KV writes |

These are **completely independent**:
- `${BASE_DOMAIN}` in an `argocd-app.yaml` → resolved by the placeholder system
- `{TUNNEL_TOKEN}` in a `secrets-expected.json` → prompted during `kuberse secrets seed` and written to Vault

## Custom Values (Beyond Placeholders)

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

## Troubleshooting

### Unresolved placeholders after setup

Run inside the CLI pod:

```bash
grep -rn '\${' /workspace/registry/ --include="*.yaml" \
  | grep -v ".git/" | grep -v "docs/"
```

If tokens remain, check:
1. Is the key present in `/etc/kuberse/`? (`ls /etc/kuberse/`)
2. Does the filename match the expected key? (e.g., `base_domain` → `${BASE_DOMAIN}`)

### Placeholder resolved to wrong value

Check the source: `cat /etc/kuberse/<key_lowercase>`

The `kuberse-config` Secret is the single source of truth:
```bash
kubectl get secret kuberse-config -n platform -o jsonpath='{.data.<key>}' | base64 -d
```
