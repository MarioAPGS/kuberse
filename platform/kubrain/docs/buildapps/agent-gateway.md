# BuildApp Agent Gateway

Kubrain provides an API gateway to interact with the OpenCode AI coding agents running inside each BuildApp pod. Instead of connecting directly to each agent or using the MCP server, you access all agent operations through a unified REST API with the BuildApp name in the URL.

> Gateway authorization is transitional. Generic and named agent gateway routes
> include explicitly public exceptions today. Restrict them at ingress and do
> not assume Kubrain's OIDC token or local permissions are propagated upstream.

## URL Convention

```
/api/v1/buildapp/:name/agent/<operation>
```

The `:name` segment identifies the target BuildApp. All subsequent path segments map to agent operations.

## Available Operations

### Health

Check if the agent inside a BuildApp is reachable:

```
GET /api/v1/buildapp/my-app/agent/health
```

### Sessions

Sessions represent interactive coding conversations with the AI agent.

| Action | Method | Path |
|--------|--------|------|
| List sessions | `GET` | `/agent/sessions` |
| Create session | `POST` | `/agent/sessions` |
| Get session | `GET` | `/agent/sessions/:sessionId` |
| Delete session | `DELETE` | `/agent/sessions/:sessionId` |
| Get TODO list | `GET` | `/agent/sessions/:sessionId/todo` |
| Abort processing | `POST` | `/agent/sessions/:sessionId/abort` |
| Get file diffs | `GET` | `/agent/sessions/:sessionId/diff` |

**Create session body:**

```json
{
  "workdir": "/workspace/my-project",
  "title": "Fix authentication bug"
}
```

### Messages

Send prompts and retrieve AI responses within a session.

| Action | Method | Path |
|--------|--------|------|
| List messages | `GET` | `/agent/sessions/:sessionId/messages` |
| Send message | `POST` | `/agent/sessions/:sessionId/messages` |
| Get message | `GET` | `/agent/sessions/:sessionId/messages/:messageId` |

**Send message body:**

```json
{
  "text": "Refactor the auth module to use JWT tokens",
  "model": "anthropic/claude-sonnet-4-20250514",
  "wait": true
}
```

The `model` field accepts three formats:
- `provider/model` — exact match (e.g. `anthropic/claude-sonnet-4-20250514`)
- `model` — auto-resolved if unique across providers (e.g. `claude-sonnet-4-20250514`)
- Setting `wait: true` blocks until the AI finishes responding

### Commands

Execute slash commands or shell commands inside the agent session.

| Action | Method | Path | Body |
|--------|--------|------|------|
| Slash command | `POST` | `/agent/sessions/:sessionId/command` | `{ "command": "/help", "arguments": "..." }` |
| Shell command | `POST` | `/agent/sessions/:sessionId/shell` | `{ "command": "npm test", "agent": "code" }` |

### Configuration

Read or update the agent configuration (model, permissions, etc.).

| Action | Method | Path |
|--------|--------|------|
| Get config | `GET` | `/agent/config` |
| Update config | `PATCH` | `/agent/config` |
| List providers | `GET` | `/agent/providers` |
| List models | `GET` | `/agent/models` |

### Files

Browse and search the workspace filesystem of the BuildApp.

| Action | Method | Path | Query Params |
|--------|--------|------|--------------|
| Search text | `GET` | `/agent/search/text` | `pattern` |
| Search files | `GET` | `/agent/search/files` | `query`, `type`, `limit` |
| Search symbols | `GET` | `/agent/search/symbols` | `query` |
| List directory | `GET` | `/agent/files` | `path` |
| Read file | `GET` | `/agent/files/content` | `path` |
| Modified files | `GET` | `/agent/files/status` | — |

### Projects

Inspect the workspace project structure and VCS state.

| Action | Method | Path |
|--------|--------|------|
| List projects | `GET` | `/agent/projects` |
| Current project | `GET` | `/agent/project` |
| Working path | `GET` | `/agent/path` |
| Git info | `GET` | `/agent/vcs` |

## Configuration

The gateway connects to agents using in-cluster DNS. Configure via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENCODE_URL_TEMPLATE` | `http://{name}-agent.{name}.svc.cluster.local:{port}` | URL template for agent pods |
| `OPENCODE_PORT` | `4096` | Agent HTTP port |
| `OPENCODE_TIMEOUT_MS` | `120000` | Request timeout in milliseconds |

## Swagger Documentation

The agent gateway endpoints are documented in the interactive Swagger UI at:

```
/api/buildapp/docs
```

## Relation to MCP

This gateway replaces the need to use the MCP server in `kuberse-api` for agent interactions. The same operations that were available as MCP tools are now accessible as standard REST endpoints, with the BuildApp name embedded in the URL path instead of passed as a parameter.
