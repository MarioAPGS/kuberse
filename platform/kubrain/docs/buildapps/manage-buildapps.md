# Manage BuildApps

BuildApps are managed from the Catalog after creation. Select a BuildApp entity to open the details panel and use the available actions.

## Find a BuildApp

1. Open `/nodes`.
2. Use the search box to find the BuildApp name.
3. Click the entity in the graph.
4. Review the details panel.

## Edit Values

BuildApp entities expose an edit action in the details panel. The edit modal loads the current BuildApp values, lets you update them, and saves the changes.

The Edit form uses the same shape as Create — the backend translates the Helm-native representation stored in ArgoCD back to the shorthand format on load, so what you see is what Create accepts. The only difference is that secret values do not round-trip: when you load values for editing, secret entries appear with their `path` (and optional `envFile`) but without `key`/`value`, because those were already written to Vault at creation time.

After saving, ArgoCD applies the desired state through GitOps sync.

### Scale-to-zero by omission

`dev`, `prod` and each entry under `services` are independent and all optional. Removing one of them from the Edit form deletes the corresponding workload natively: the buildapp chart renders no resources for the omitted block, and ArgoCD prunes anything previously created. There is no separate "disable" toggle — the absence of the block IS the disable.

This lets you, for example:

- Edit a buildapp to drop `prod` while keeping `dev` for active development.
- Remove a stale service (e.g. `postgres`) without touching the others.
- Send an empty values body to scale the whole environment to zero while keeping its identity, secrets policy and namespace.

### Adding new secrets while editing

You can add new secret entries in the Edit modal — any entry that includes `key`, `value` and `path` will be written to Vault (merging with existing keys under the same path). Entries without `key`/`value` are left untouched.

Use this when you need to:

- Add or remove services.
- Change resource requests or limits.
- Add ports.
- Update secrets or environment configuration.
- Change storage sizes or images.

## Delete a BuildApp

BuildApp entities also expose a delete action. Deleting a BuildApp removes the environment and its associated platform resources.

The backend handles cleanup for:

- BuildApp catalog entities
- ArgoCD application resources
- Namespace/resources belonging to the BuildApp
- Vault policies, roles, and secrets associated with the BuildApp

## Inspect Runtime State

If the BuildApp has an ArgoCD application, open its ArgoCD resource graph from the entity details panel. Use that view to inspect workloads, manifests, logs, health, and sync state.

## Practical Advice

- Keep BuildApp names short and DNS-compatible.
- Prefer explicit resource requests/limits to avoid noisy-neighbor problems.
- Put reusable configuration in the JSON values rather than editing live resources.
- For permanent changes, update the BuildApp values instead of changing Kubernetes resources directly.
