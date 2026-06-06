# Kuberse Registry

**Your private Kubernetes platform in a single fork.**

Kuberse is a GitOps-driven platform that deploys a full production stack — secrets management, SSO, databases, observability, networking, and AI services — onto any Kubernetes cluster. This repository is the **registry**: fork it, run the CLI, and get a fully configured platform.

## How It Works

```
Fork this repo → kuberse init → kuberse setup → Platform deployed
```

1. **Fork** this repository into your GitHub organization (or Gitea instance)
2. **Run `kuberse init`** on your machine — provisions a cluster and deploys the CLI pod
3. **Run `kuberse setup`** inside the pod — resolves templates with your configuration, seeds secrets into Vault, and deploys ArgoCD
4. **ArgoCD takes over** — reads this repo and reconciles all platform components automatically

Every file in this repo is a template. Placeholders like `${BASE_DOMAIN}`, `${ORG_NAME}`, and `${REGISTRY_URL}` get replaced with your values during setup. After that, ArgoCD treats this repo as the single source of truth.

## What You Get

| Category | Components |
|----------|------------|
| **Core** | ArgoCD (GitOps), Vault (secrets), PostgreSQL (databases), Authentik (SSO/OIDC) |
| **Networking** | ingress-nginx, Cloudflare Tunnel (plugin) |
| **Observability** | Grafana, Loki, Mimir (plugin) |
| **AI** | LiteLLM router, LangGraph agents, Copilot wrapper (plugin) |
| **Apps** | Kubrain (control plane), Playhouse (dev environments), CloudBeaver (DB UI) |

## Repository Structure

```
├── bootstrap.yaml              # Root ArgoCD Application (entry point)
├── platform/                   # Core platform ArgoCD apps
│   ├── argocd-app-of-apps.yaml
│   ├── vault/
│   ├── postgres/
│   ├── authentik/
│   ├── ingress-nginx/
│   ├── kubrain/
│   └── ...
├── plugins/                    # Installed plugin manifests
│   ├── _template/              # Plugin starter template
│   └── _app/                   # Kubrain remote UI template
├── scripts/                    # Utility scripts
└── docs/                       # Full documentation
```

## Documentation

| Section | Description |
|---------|-------------|
| [Architecture](docs/architecture.md) | Platform design, component map, and data flows |
| [Quick Start](docs/getting-started/quickstart.md) | Fork-to-deploy in 10 minutes |
| [GitOps Flow](docs/concepts/gitops-flow.md) | How bootstrap.yaml drives the entire platform |
| [Placeholder System](docs/concepts/placeholders.md) | Template variables and customization |
| [Platform Components](docs/platform/overview.md) | Every component explained |
| [Plugin System](docs/plugins/overview.md) | Install, manage, and author plugins |
| [CLI Reference](docs/cli/reference.md) | All commands and flags |

## Quick Start

### Prerequisites

- Docker (or Podman)
- `kubectl`, `helm`, `oras` CLI tools
- A domain with DNS control (for production) or `*.localhost` (for local dev)
- GitHub account or self-hosted Gitea

### Deploy

```bash
# 1. Fork this repo to your org
gh repo fork kuberse/kuberse-registry --org=my-org

# 2. Initialize cluster and CLI pod
kuberse init --provider=github --cluster-mode=minikube

# 3. Setup platform (interactive — prompts for domain, email, etc.)
kuberse setup
```

After setup completes, access ArgoCD at `https://argocd.${YOUR_DOMAIN}` and watch all services sync.

## Extending with Plugins

```bash
# List available plugins
kuberse plugin list --available

# Install networking (Cloudflare Tunnel)
kuberse plugin install kuberse-networking

# Install observability (Grafana + Loki + Mimir)
kuberse plugin install kuberse-observability
```

Plugins are OCI-packaged Helm charts with ArgoCD manifests. See [Plugin System](docs/plugins/overview.md) for details.

## Related Repositories

| Repository | Purpose |
|------------|---------|
| [kuberse-helm](https://github.com/kuberse/kuberse-helm) | CLI source code, Helm charts, platform charts |
| [kuberse-networking](https://github.com/kuberse/kuberse-networking) | Cloudflare Tunnel plugin |
| [kuberse-observability](https://github.com/kuberse/kuberse-observability) | Grafana + Loki + Mimir plugin |
| [kuberse-ai](https://github.com/kuberse/kuberse-ai) | AI infrastructure plugin |
| [kubrain](https://github.com/kuberse/kubrain) | Platform control plane & app hub |

## License

Private — see LICENSE file.
