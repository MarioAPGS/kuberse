# Kubrain Authentication and Authorization

Kubrain authenticates browser and API requests with JWT access tokens from one
or more explicitly configured external OIDC providers. The browser performs
Authorization Code + PKCE; Kubrain does not issue tokens, keep login sessions,
use authentication cookies, or store JWTs.

## Request flow

1. The SPA reads public `GET /api/v1/auth/config`.
2. The user selects a configured provider and completes Authorization Code +
   PKCE in the browser.
3. The SPA sends the JWT access token as strict `Bearer <token>` syntax in the
   configured header.
4. The API verifies signature, exact issuer, audience, expiry and optional
   `nbf`, then resolves the configured subject claim.
5. Kubrain upserts a local `(providerId, subject)` identity and evaluates its
   database-backed permissions.

Use an access token, not an ID token. Kubrain does not map groups, roles or
permissions from token claims.

## Browser endpoints

- `GET /api/v1/auth/config` is public. It returns `enabled`, the bearer header
  name, and browser-required provider metadata, but never secrets or
  permissions.
- `GET /api/v1/auth/me` requires authentication but no domain permission. It
  returns the effective identity, profile fields, mode flags and permissions,
  but never the JWT or internal UUID.

## Identities and permissions

OIDC identities are persisted locally on their first valid request. A new OIDC
identity has no permissions and receives `403` from protected domain endpoints
until an operator grants permissions in PostgreSQL. There is currently no
permission-management API or group-to-permission mapping.

Permissions are hierarchical:

- `catalog.read` grants one action.
- `catalog.*` grants every action in exactly that domain.
- `*` grants everything and is reserved for system identities.

Supported domains include catalog, ingestion, ArgoCD, BuildApps, Vault, docs,
agents and gateway refresh. Permission data is cached for one hour per replica;
urgent grants or revocations require restarting all replicas or waiting for the
cache TTL.

## Anonymous mode

An empty `auth.providers` list enables the reserved `internal/anonymous`
identity with `*`. Supplied bearer headers are ignored in this mode. This is a
backward-compatibility administrator mode, **not** guest or read-only access.
Adding any provider disables anonymous identity selection immediately; there is
no `allowAnonymous` fallback.

Before enabling the first provider, verify redirect URI, issuer and audience,
retain database recovery access, and establish how operators will grant the
first users permissions.

## Helm configuration

The Kubrain chart owns both the runtime provider configuration and the bundled
Authentik client declaration:

```yaml
kubrain:
  authentikOidc:
    enabled: true
    issuer: "https://auth.${BASE_DOMAIN}/application/o/kubrain/"
    redirectUris:
      - url: "https://kubrain.${BASE_DOMAIN}/auth/callback"
        matchingMode: strict
    provider:
      clientType: public
      clientId: kubrain
      subMode: hashed_user_id
    application:
      launchUrl: "https://kubrain.${BASE_DOMAIN}"

  configFile:
    enabled: true
    content: |
      auth:
        providers:
          - id: authentik
            displayName: Authentik
            issuer: https://auth.${BASE_DOMAIN}/application/o/kubrain/
            audience: kubrain
            clientId: kubrain
            subjectClaim: sub
            scopes: [openid, profile, email]
```

`auth.providers` accepts multiple entries. If authorization, token or JWKS
endpoints are omitted, Kubrain fills missing metadata from OIDC discovery at
startup. Manual endpoint values take precedence. No client secret belongs in
the configuration because the SPA is a public PKCE client.

The bearer header defaults to `Authorization`. Set it through the chart's
deployment environment to use an ingress-safe custom name:

```yaml
kubrain:
  env:
    - name: KUBRAIN_BEARER_TOKEN_HEADER
      value: X-Kubrain-Token
```

`/auth/config` tells the SPA which header to send. Never log it.

To intentionally retain anonymous mode, set `auth.providers: []` and disable
`authentikOidc` if no Authentik application should be provisioned.

## Temporary public gateway exceptions

Swagger UI/JSON, the generic proxy `/api/v1/:serviceName/*`, agent discovery
`/api/v1/agents`, and the agent proxy `/agents/v1/:agentName/*` are explicitly
public for now. These exceptions can expose upstream data and may forward
headers. Restrict them at ingress until gateway-specific authorization is
implemented; do not treat their current behavior as an authorization contract.

## Troubleshooting

- `401`: check the configured header and exact `Bearer` prefix, exact issuer
  (including trailing slash), access-token audience, signing keys and expiry.
- `403`: authentication succeeded but the local identity lacks the required
  permission; account for the per-replica cache after a grant.
- Startup discovery failure: verify issuer reachability/TLS or configure the
  missing authorization, token and JWKS endpoints manually.
