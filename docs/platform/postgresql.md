# PostgreSQL

## Role in the Platform

PostgreSQL provides a **centralized database** for all platform services that need persistent relational storage (Authentik, Kubrain, Grafana, etc.).

## Auto-Provisioning

You never create databases manually. The platform uses a CronJob-based provisioner:

1. A chart ships a Secret labeled `db-provision: "true"`
2. The provisioner CronJob (every 5 min) discovers labeled Secrets
3. It connects to PostgreSQL and runs `CREATE DATABASE` + `CREATE USER`
4. The application reads credentials from the same Secret

```yaml
# Example: declaring a database need in a Helm chart
apiVersion: v1
kind: Secret
metadata:
  name: my-app-db
  labels:
    db-provision: "true"
stringData:
  POSTGRES_DB: my_app
  POSTGRES_USER: my_app
  POSTGRES_PASSWORD_KEY: kuberse/my-app  # Vault path for the password
```

## Connecting from Applications

Applications connect using standard `DATABASE_URL` environment variables, populated by the combination of:
- Database name/user from the provisioner Secret
- Password from Vault (via VaultStaticSecret → Kubernetes Secret)

## Accessing via CloudBeaver

CloudBeaver provides a web UI for database inspection:

```
https://cloudbeaver.${BASE_DOMAIN}
```

It's pre-configured to connect to the platform PostgreSQL instance.
