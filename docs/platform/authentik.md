# Authentik

## Role in the Platform

Authentik is the platform's bundled identity provider. Services can use its
OIDC/OAuth2 flows, while Kubrain also supports additional external OIDC
providers configured independently.

## What It Provides

- **Single Sign-On** — Login once, access all services
- **OIDC Provider** — Standard OpenID Connect for ArgoCD, Grafana, Kubrain, etc.
- **User Management** — Admin UI for managing users, groups, and permissions
- **Flow-based Auth** — Customizable login/enrollment/recovery flows

## Pre-configured OIDC Clients

After setup, these OIDC providers are created automatically:

| Client | Service | Redirect URI |
|--------|---------|--------------|
| `argocd` | ArgoCD | `https://argocd.${BASE_DOMAIN}/auth/callback` |
| `grafana` | Grafana | `https://grafana.${BASE_DOMAIN}/login/generic_oauth` |
| `kubrain` | Kubrain public SPA | `https://kubrain.${BASE_DOMAIN}/auth/callback` |

### Kubrain client

Kubrain declares its Authentik application through the chart's
label-discovered OIDC ConfigMap. The client is **public** and uses Authorization
Code + PKCE, so it has no client secret to store in Vault or expose to the
browser. Its client ID is also the expected JWT access-token audience. Kubrain
validates the access token and keeps authorization permissions locally; it does
not derive permissions from Authentik groups or arbitrary token claims.

The issuer is the per-application URL and must retain its trailing slash:

```text
https://auth.${BASE_DOMAIN}/application/o/kubrain/
```

See [Kubrain](kubrain.md) for provider and Helm configuration.

## Accessing

```
https://auth.${BASE_DOMAIN}
```

Admin login with credentials from Vault at `kuberse/authentik`.

## Adding SSO to a New Service

1. Create an OIDC provider in Authentik (via UI or API)
2. Store the client secret in Vault
3. Configure your service to use:
   - Discovery URL: `https://auth.${BASE_DOMAIN}/application/o/<slug>/.well-known/openid-configuration`
   - Client ID and secret from Vault
