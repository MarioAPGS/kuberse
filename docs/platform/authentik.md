# Authentik

## Role in the Platform

Authentik is the **identity provider** for the entire platform. Every service that has a web UI authenticates users through Authentik's OIDC/OAuth2 flows.

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
| `kubrain` | Kubrain | `https://kubrain.${BASE_DOMAIN}/api/auth/callback` |

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
