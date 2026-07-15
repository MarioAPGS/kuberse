# Troubleshooting Guide

## ArgoCD OIDC Login Fails (HTML instead of JSON)

Kuberse uses Authentik (an identity provider deployed as part of the platform) to provide single sign-on to ArgoCD and other services. It uses OIDC (OpenID Connect) for authentication, which requires ArgoCD to reach Authentik's discovery endpoint.

**Symptom**: Clicking "Log in via Authentik" in ArgoCD shows an error about expected JSON but got HTML with a `<` character.

**Cause**: The hostname `auth.<base_domain>` is resolving to Cloudflare public IPs instead of the in-cluster ingress ClusterIP. This happens when the CoreDNS hairpin entry is missing — the OIDC provisioner Job may have completed "successfully" but failed to actually patch CoreDNS.

**Diagnosis** (run these commands):

```bash
# Check if CoreDNS has the hairpin entry
kubectl -n kube-system get cm coredns -o jsonpath='{.data.Corefile}' | grep auth.<your-domain>

# Check DNS resolution from inside cluster
kubectl -n platform exec vault-0 -- nslookup auth.<your-domain>
# Should return a ClusterIP (10.43.x.x), NOT public IPs

# Test the OIDC endpoint directly
kubectl -n platform exec vault-0 -- wget -qO- --no-check-certificate \
  https://auth.<your-domain>/application/o/argocd/.well-known/openid-configuration | head -c 200
# Should return JSON, not HTML
```

**Manual fix**:

1. Get the ingress ClusterIP: `kubectl -n platform get svc ingress-nginx-controller -o jsonpath='{.spec.clusterIP}'`
2. Edit CoreDNS ConfigMap: `kubectl -n kube-system edit cm coredns`
3. Add `<CLUSTER_IP> auth.<your-domain>` inside the `hosts { ... }` block before `fallthrough`
4. Restart CoreDNS: `kubectl -n kube-system rollout restart deployment/coredns`
5. Restart ArgoCD: `kubectl -n argocd rollout restart deployment/argocd-server`

**Root cause detail**: The provisioner script uses a regex to inject the entry. On k3s clusters the CoreDNS config format differs slightly (uses `hosts /etc/coredns/NodeHosts {` instead of `hosts {`), which caused the regex to silently fail. This has been fixed in newer versions.

---

## Common Issues

### CLI pod doesn't start

- **Cause**: Can't pull `ghcr.io/marioapgs/kuberse/img/kuberse-cli:latest`
- **Fix**: Ensure cluster nodes can reach ghcr.io. On k3s, check from the server VM.

### `kuberse setup` fails partway

- **Fix**: Re-run is safe. Every phase is idempotent. Just exec back in: `kuberse cli` then `kuberse setup`.

### ArgoCD shows Degraded applications after initial setup

- **Cause**: Usually transient. Vault module-config Job may not have completed yet.
- **Fix**: Wait 2-3 minutes, then check: `kubectl get applications -n argocd`
- If persists, manually trigger: `kubectl -n platform create job vault-module-config-manual --from=cronjob/vault-module-config`

### VaultStaticSecret not syncing

- **Cause**: Per-module Vault policy/role may not exist yet.
- **Fix**: Check if vault-module-config CronJob has run: `kubectl -n platform get jobs | grep vault-module-config`
- Trigger manually if needed (see above).

### k3s: kubectl commands fail after init

- **Cause**: KUBECONFIG not set in your shell.
- **Fix**: `export KUBECONFIG=$HOME/.kube/config-kuberse`

### Gitea mode: ArgoCD can't pull charts

- **Cause**: OCI credentials may not be configured correctly for plain HTTP.
- **Fix**: Check `kubectl -n argocd get secret gitea-oci-creds -o yaml` — the URL must start with `oci://`.

### `kuberse update --artifacts` does nothing

- **Note**: This flag is currently a stub for Gitea installations. After syncing with upstream, you may need to manually mirror new chart versions.

### Browser shows `ERR_CERT_AUTHORITY_INVALID` on `https://*.<domain>:30443`

- **Cause**: Accessed over the internal DNS, ingress-nginx serves its self-signed
  *"Kubernetes Ingress Controller Fake Certificate"*, which the browser does not trust.
- **Fix**: Serve a browser-trusted certificate as the ingress default:
  1. On the operator machine, run `kuberse local-ssl setup`. This installs a local
     CA (mkcert) into your OS/browser trust stores, generates a wildcard cert for
     `*.<domain>`, and creates the `platform/kuberse-local-tls` TLS Secret.
  2. Enable the opt-in flag in `platform/ingress-nginx/argocd-app.yaml` — under the
     inline Helm `values`, uncomment `default-ssl-certificate: platform/kuberse-local-tls`
     inside `controller.extraArgs`. Commit and push; ArgoCD applies it on the next sync.
- **Important**: Only enable the flag **after** the `kuberse-local-tls` Secret exists.
  Referencing a missing Secret prevents the ingress controller from starting.
- **Browser note**: Restart the browser (fully quit, not just the window) so it
  reloads the trust store. Brave/Chrome/Firefox on Linux read the mkcert CA from
  `~/.pki/nssdb` (requires `libnss3-tools`/`nss-tools`, installed by `local-ssl setup`).
