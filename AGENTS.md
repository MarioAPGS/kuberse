# AGENTS.md

## Identity

You are working in the **kuberse registry** repository. This is the forkable template that becomes a user's platform source of truth. ArgoCD reads this repo to deploy and manage all cluster services.

## Critical Rules

- **Never** hardcode values that should be placeholders — use `${PLACEHOLDER}` tokens
- **Never** modify `bootstrap.yaml` structure without understanding the 3-level app-of-apps hierarchy
- **Never** add secrets or credentials to any file
- **Always** use `ServerSideApply=true` in ArgoCD Application syncOptions
- **Always** set appropriate sync wave annotations on new Applications
- **Documentation** is a first-class citizen — update `docs/` when changing platform behavior

## Structure

```
bootstrap.yaml          # Root ArgoCD Application (entry point)
platform/               # Core platform ArgoCD apps
  argocd-app-of-apps.yaml
  vault/argocd-app.yaml
  postgres/argocd-app.yaml
  authentik/argocd-app.yaml
  ...
plugins/                # Installed plugin manifests (+ templates)
  _template/            # Plugin starter template
  _app/                 # Kubrain remote UI template
  docs/                 # Plugin authoring guides
docs/                   # Full platform documentation
  architecture.md
  concepts/             # GitOps flow, placeholders
  getting-started/      # Quickstart
  platform/             # Component docs (vault, argocd, pg, authentik)
  plugins/              # Plugin system overview
  cli/                  # CLI reference, troubleshooting
cli/docs/               # Legacy location (kept for backward compat)
scripts/                # Utility scripts
```

## Conventions

- All YAML files are templates with `${PLACEHOLDER}` tokens
- Sync waves: -1 (namespaces) → 0 (replicator) → 1 (vault, pg, ingress) → 2 (authentik, argocd-config) → 3 (apps) → 4 (plugins)
- Each platform service = one directory with one `argocd-app.yaml`
- Plugin docs travel with the plugin (`template/docs/`) and are copied here during install
- Documentation language: English

## Documentation

- `docs/index.md` — Entry point to all documentation
- `docs/architecture.md` — Platform design with Mermaid diagrams
- `docs/concepts/` — Core concepts (GitOps flow, placeholders)
- `docs/platform/` — Component reference (vault, argocd, pg, authentik)
- `docs/plugins/overview.md` — Plugin system
- `docs/cli/` — CLI reference and troubleshooting
- `plugins/docs/plugins.md` — Advanced plugin authoring guide (731 lines)

## Placeholder Reference

| Placeholder | Description |
|-------------|-------------|
| `${BASE_DOMAIN}` | Platform domain (e.g., `mycompany.dev`) |
| `${ORG_NAME}` | GitHub/Gitea org name |
| `${REGISTRY_URL}` | OCI registry host (e.g., `ghcr.io`) |
| `${GIT_BASE_URL}` | Git server URL (e.g., `https://github.com`) |
| `${ADMIN_EMAIL}` | Platform admin email |
| `${GIT_PROVIDER}` | `github` or `gitea` |
| `${PLATFORM_VERSION}` | Platform chart version |
| `${KUBERSE_<PLUGIN>_VERSION}` | Plugin chart versions |
