# API Endpoints Reference

This reference lists the user-facing API areas that power Kubrain's UI. Most users interact through the frontend, but these endpoints explain what each screen uses.

Except for routes explicitly identified as public, requests require a verified
OIDC access token (when providers are configured) and the endpoint's local
permission.

## Authentication

| Method | Path | Access | Purpose |
|--------|------|--------|---------|
| `GET` | `/api/v1/auth/config` | Public | Browser-safe provider and bearer-header configuration |
| `GET` | `/api/v1/auth/me` | Authenticated | Effective identity and local permissions |

In anonymous mode, `/auth/me` returns the reserved `internal/anonymous` system
identity. See the [authentication guide](../../../../docs/platform/kubrain.md).

## Catalog

| Method | Path | Used By |
|--------|------|---------|
| `GET` | `/api/v1/entities` | Load catalog entities and relations |
| `GET` | `/api/v1/entities/:entityRef` | Load one entity for the details panel |
| `GET` | `/api/v1/entities/:entityRef/relations` | Load relationships for one entity |
| `PATCH` | `/api/v1/entities/:entityRef/store` | Update persistent entity store/status |
| `DELETE` | `/api/v1/entities/:entityRef` | Delete an entity |

## ArgoCD Resources

| Method | Path | Used By |
|--------|------|---------|
| `GET` | `/api/v1/argocd/:app` | Application overview |
| `GET` | `/api/v1/argocd/:app/nodes` | Resource graph |
| `POST` | `/api/v1/argocd/:app/sync` | Sync application |
| `GET` | `/api/v1/argocd/:app/:resource` | Resource details |
| `GET` | `/api/v1/argocd/:app/:resource/manifest` | View resource manifest |
| `GET` | `/api/v1/argocd/:app/:resource/logs` | View logs |
| `POST` | `/api/v1/argocd/:app/:resource/sync` | Sync resource subtree |
| `DELETE` | `/api/v1/argocd/:app/:resource` | Delete live resource |

## BuildApps

| Method | Path | Used By |
|--------|------|---------|
| `POST` | `/api/v1/buildapp` | Create BuildApp |
| `GET` | `/api/v1/buildapp` | List BuildApps |
| `GET` | `/api/v1/buildapp/:name/values` | Load BuildApp values for editing |
| `PATCH` | `/api/v1/buildapp/:name/values` | Save edited values |
| `GET` | `/api/v1/buildapp/:name/status` | Read BuildApp health/sync status |
| `DELETE` | `/api/v1/buildapp/:name` | Delete BuildApp |

## BuildApp Agent Gateway

Kubrain acts as an API gateway to OpenCode agents running inside BuildApp pods. All agent endpoints require the BuildApp name in the URL path.

| Method | Path | Used By |
|--------|------|---------|
| `GET` | `/api/v1/buildapp/:name/agent/health` | Agent health check |
| `GET` | `/api/v1/buildapp/:name/agent/sessions` | List coding sessions |
| `POST` | `/api/v1/buildapp/:name/agent/sessions` | Create a new session |
| `GET` | `/api/v1/buildapp/:name/agent/sessions/:sessionId` | Get session details |
| `DELETE` | `/api/v1/buildapp/:name/agent/sessions/:sessionId` | Delete session |
| `GET` | `/api/v1/buildapp/:name/agent/sessions/:sessionId/todo` | Get agent TODO list |
| `POST` | `/api/v1/buildapp/:name/agent/sessions/:sessionId/abort` | Abort current processing |
| `GET` | `/api/v1/buildapp/:name/agent/sessions/:sessionId/diff` | Get file diffs |
| `GET` | `/api/v1/buildapp/:name/agent/sessions/:sessionId/messages` | List messages |
| `POST` | `/api/v1/buildapp/:name/agent/sessions/:sessionId/messages` | Send message to AI |
| `GET` | `/api/v1/buildapp/:name/agent/sessions/:sessionId/messages/:messageId` | Get specific message |
| `POST` | `/api/v1/buildapp/:name/agent/sessions/:sessionId/command` | Execute slash command |
| `POST` | `/api/v1/buildapp/:name/agent/sessions/:sessionId/shell` | Execute shell command |
| `GET` | `/api/v1/buildapp/:name/agent/config` | Get agent config |
| `PATCH` | `/api/v1/buildapp/:name/agent/config` | Update agent config |
| `GET` | `/api/v1/buildapp/:name/agent/providers` | List AI providers |
| `GET` | `/api/v1/buildapp/:name/agent/models` | List available models |
| `GET` | `/api/v1/buildapp/:name/agent/search/text` | Search text in files |
| `GET` | `/api/v1/buildapp/:name/agent/search/files` | Search files by name |
| `GET` | `/api/v1/buildapp/:name/agent/search/symbols` | Search code symbols |
| `GET` | `/api/v1/buildapp/:name/agent/files` | List directory contents |
| `GET` | `/api/v1/buildapp/:name/agent/files/content` | Read file content |
| `GET` | `/api/v1/buildapp/:name/agent/files/status` | Get modified files |
| `GET` | `/api/v1/buildapp/:name/agent/projects` | List projects |
| `GET` | `/api/v1/buildapp/:name/agent/project` | Get current project |
| `GET` | `/api/v1/buildapp/:name/agent/path` | Get working directory |
| `GET` | `/api/v1/buildapp/:name/agent/vcs` | Get git info |

## Docs

| Method | Path | Used By |
|--------|------|---------|
| `GET` | `/api/v1/docs` | List Doc entities |
| `GET` | `/api/v1/docs/:entityRef` | Load one Doc entity |
| `GET` | `/api/v1/docs/:entityRef/content?path=<file>` | Fetch markdown content |

## Platform Secrets

Kubrain also exposes operator-facing Vault secret endpoints. These are not currently exposed as a dedicated frontend page.

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/v1/vault/secrets/platform/*` | Store platform secrets under Vault KV v2 |

## Temporary Public Gateway Exceptions

The generic service proxy `/api/v1/:serviceName/*`, agent discovery
`/api/v1/agents`, agent proxy `/agents/v1/:agentName/*`, and Swagger UI/JSON are
currently public exceptions. Restrict them at ingress until gateway-specific
authorization is implemented.
