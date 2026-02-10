# n8n Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/n8n-helm)](https://artifacthub.io/packages/search?repo=n8n-helm)

> **Warning:** This chart is a work in progress and not yet ready for production use.

A Helm chart for deploying [n8n](https://n8n.io) workflow automation on Kubernetes.

## Architecture

By default the chart deploys a single n8n main pod using SQLite. Set `worker.replicas > 0` to enable queue mode with separate workers. Enable `webhook.enabled` to add dedicated webhook processors.

| Setup | Components | Database | Redis |
|-------|-----------|----------|-------|
| Default | 1 main pod | SQLite or PostgreSQL | No |
| Workers | main + N workers | PostgreSQL | Yes |
| Workers + webhooks | main + N workers + N webhook processors | PostgreSQL | Yes |
| Multi-main (HA) | M mains + N workers | PostgreSQL | Yes |

Dashed boxes are optional. Without workers, SQLite can be used and Redis is not needed.

```mermaid
graph TD
    subgraph main_box["main [main.replicas: 1+]"]
        M[n8n main]:::comp
    end

    subgraph worker_box["workers [worker.replicas>0]"]
        W[n8n worker x N]:::comp
    end

    subgraph webhook_box["webhooks [webhook.enabled: true]"]
        WH[webhook processor x N]:::comp
    end

    PG[(PostgreSQL)]:::infra
    Redis[(Redis)]:::infra

    subgraph s3_box["S3 [externalS3.enabled: true]"]
        S3[(S3 bucket)]:::infra
    end

    M --- PG
    W --- PG
    WH --- PG
    M --- Redis
    W --- Redis
    WH --- Redis
    M -.- S3
    W -.- S3

    classDef comp fill:#ede9fe,stroke:#7c3aed,color:#5b21b6
    classDef infra fill:#dbeafe,stroke:#2563eb,color:#1e40af
    style main_box fill:#fef3c7,stroke:#d97706,color:#92400e
    style worker_box fill:#fefce8,stroke:#d97706,color:#92400e,stroke-dasharray: 5 5
    style webhook_box fill:#fefce8,stroke:#d97706,color:#92400e,stroke-dasharray: 5 5
    style s3_box fill:#fefce8,stroke:#d97706,color:#92400e,stroke-dasharray: 5 5
```

### Task runners

Task runners execute workflow code in any setup. Two modes:

- **internal** (default): runners execute inside the worker process
- **external**: runners run as sidecar containers alongside the main pod (no workers) or each worker pod (with workers), using the `n8nio/n8n-runner` image

External runners support language selection (javascript, python) passed as CMD args. You can run a single runner handling both languages or split them into separate containers with per-language images.

## Installation

```bash
helm install n8n oci://ghcr.io/atheo-ingenierie/charts/n8n --version <tag>
```

To install from source:

```bash
helm install n8n .
```

## Examples

### Minimal (standalone with SQLite)

```yaml
# values-standalone.yaml
persistence:
  enabled: true
secret:
  N8N_ENCRYPTION_KEY: "change-me-to-a-random-string"
```

### Standalone with PostgreSQL

```yaml
# values-standalone-pg.yaml
database:
  type: postgresdb
  postgresdb:
    host: postgres.default.svc
    database: n8n
    user: n8n
    password: "my-password"
secret:
  N8N_ENCRYPTION_KEY: "change-me-to-a-random-string"
```

### With workers (internal runners)

```yaml
# values-queue.yaml
database:
  type: postgresdb
  postgresdb:
    host: postgres.default.svc
    database: n8n
    user: n8n
    password: "my-password"
externalRedis:
  host: redis.default.svc
worker:
  replicas: 3
secret:
  N8N_ENCRYPTION_KEY: "change-me-to-a-random-string"
```

### With workers and external runners (split by language)

```yaml
# values-queue-external.yaml
database:
  type: postgresdb
  postgresdb:
    host: postgres.default.svc
    database: n8n
    user: n8n
    existingSecret: my-db-secret
    existingSecretPasswordKey: password
externalRedis:
  host: redis.default.svc
  existingSecret: my-redis-secret
  existingSecretPasswordKey: redis-password
runners:
  mode: external
  authToken: "my-runner-secret-token"
  containers:
    - languages: ["javascript"]
      image:
        repository: n8nio/n8n-runner-js
    - languages: ["python"]
      image:
        repository: n8nio/n8n-runner-python
worker:
  replicas: 3
webhook:
  enabled: true
  replicas: 2
secret:
  N8N_ENCRYPTION_KEY: "change-me-to-a-random-string"
```

### With workers and S3 binary storage

```yaml
# values-queue-s3.yaml
database:
  type: postgresdb
  postgresdb:
    host: postgres.default.svc
    database: n8n
    user: n8n
    password: "my-password"
externalRedis:
  host: redis.default.svc
externalS3:
  enabled: true
  host: s3.us-east-1.amazonaws.com
  bucketName: my-n8n-bucket
  bucketRegion: us-east-1
  accessKey: "AKIAIOSFODNN7EXAMPLE"
  accessSecret: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
worker:
  replicas: 3
secret:
  N8N_ENCRYPTION_KEY: "change-me-to-a-random-string"
```

### With Redis authentication

```yaml
# values-redis-auth.yaml
database:
  type: postgresdb
  postgresdb:
    host: postgres.default.svc
    database: n8n
    user: n8n
    password: "my-password"
externalRedis:
  host: redis.default.svc
  existingSecret: my-redis-secret
  existingSecretPasswordKey: redis-password
worker:
  replicas: 3
webhook:
  enabled: true
  replicas: 2
secret:
  N8N_ENCRYPTION_KEY: "change-me-to-a-random-string"
```

### Multi-main (HA)

Multiple main instances for high availability. One is elected leader (runs triggers + pruning), the rest handle API/UI/webhooks. Requires sticky sessions at the ingress level (e.g. `nginx.ingress.kubernetes.io/affinity: cookie`).

```yaml
# values-multi-main.yaml
database:
  type: postgresdb
  postgresdb:
    host: postgres.default.svc
    database: n8n
    user: n8n
    password: "my-password"
externalRedis:
  host: redis.default.svc
main:
  replicas: 3
  multiMain:
    ttl: 10
    checkInterval: 3
worker:
  replicas: 3
ingress:
  enabled: true
  className: nginx
  annotations:
    nginx.ingress.kubernetes.io/affinity: cookie
  hosts:
    - host: n8n.example.com
      paths:
        - path: /
          pathType: Prefix
secret:
  N8N_ENCRYPTION_KEY: "change-me-to-a-random-string"
```

## Values reference

### General

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | n8n image repository | `n8nio/n8n` |
| `image.tag` | n8n image tag | `appVersion` |
| `config` | n8n env vars (ConfigMap) | `{}` |
| `secret` | Sensitive n8n env vars (Secret) | `{}` |

### Database

| Parameter | Description | Default |
|-----------|-------------|---------|
| `database.type` | `sqlite` or `postgresdb` | `sqlite` |
| `database.postgresdb.host` | PostgreSQL host | `""` |
| `database.postgresdb.port` | PostgreSQL port | `5432` |
| `database.postgresdb.database` | Database name | `n8n` |
| `database.postgresdb.user` | Database user | `n8n` |
| `database.postgresdb.password` | Database password (plain text) | `""` |
| `database.postgresdb.existingSecret` | Existing secret name for DB password | `""` |
| `database.postgresdb.existingSecretPasswordKey` | Key in the existing secret | `password` |

### Task runners

| Parameter | Description | Default |
|-----------|-------------|---------|
| `runners.mode` | `internal` or `external` | `internal` |
| `runners.authToken` | Shared auth token between worker and runners (required for external) | `""` |
| `runners.image.repository` | Default runner image | `n8nio/n8n-runner` |
| `runners.image.tag` | Default runner tag | `appVersion` |
| `runners.resources` | Resources for all runner sidecars | `{}` |
| `runners.extraEnv` | Extra env vars for all runner sidecars | `[]` |
| `runners.containers` | List of runner sidecar definitions | 1 runner with `[javascript, python]` |
| `runners.containers[].languages` | Languages for this runner (CMD args) | - |
| `runners.containers[].image` | Optional image override for this runner | - |

### Components

| Parameter | Description | Default |
|-----------|-------------|---------|
| `main.replicas` | Number of main pods (>1 enables multi-main HA, requires workers) | `1` |
| `main.multiMain.ttl` | Leader key TTL in seconds | `10` |
| `main.multiMain.checkInterval` | Leader check interval in seconds | `3` |
| `main.resources` | Main process resources | `{}` |
| `main.extraEnv` | Extra env vars for main | `[]` |
| `worker.replicas` | Number of worker pods (>0 enables queue mode, requires PostgreSQL + Redis) | `0` |
| `worker.concurrency` | Max concurrent executions per worker (`--concurrency`) | `10` |
| `worker.resources` | Worker resources | `{}` |
| `worker.extraEnv` | Extra env vars for workers | `[]` |
| `webhook.enabled` | Enable webhook processors | `false` |
| `webhook.replicas` | Number of webhook pods | `2` |
| `webhook.url` | External webhook URL (defaults to `https://<ingress host>`) | `""` |
| `webhook.resources` | Webhook resources | `{}` |
| `webhook.extraEnv` | Extra env vars for webhooks | `[]` |

All components also support `podAnnotations`, `podLabels`, `nodeSelector`, `tolerations`, and `affinity`.

### External S3

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalS3.enabled` | Enable S3 binary data storage | `false` |
| `externalS3.host` | S3 host (e.g. `s3.us-east-1.amazonaws.com`) | `""` |
| `externalS3.bucketName` | S3 bucket name | `""` |
| `externalS3.bucketRegion` | S3 bucket region | `""` |
| `externalS3.accessKey` | S3 access key (plain text) | `""` |
| `externalS3.accessSecret` | S3 access secret (plain text) | `""` |
| `externalS3.existingSecret` | Existing secret for S3 credentials | `""` |
| `externalS3.existingSecretAccessKeyKey` | Key for access key in existing secret | `access-key` |
| `externalS3.existingSecretAccessSecretKey` | Key for access secret in existing secret | `access-secret` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable PVC for n8n data (single main only) | `false` |
| `persistence.size` | PVC size | `1Gi` |
| `persistence.storageClass` | Storage class | `""` |
| `persistence.accessModes` | PVC access modes | `[ReadWriteOnce]` |

### External Redis

| Parameter | Description | Default |
|-----------|-------------|---------|
| `externalRedis.host` | Redis host (required when workers or webhooks enabled) | `""` |
| `externalRedis.port` | Redis port | `6379` |
| `externalRedis.password` | Redis password (plain text) | `""` |
| `externalRedis.existingSecret` | Existing secret for Redis password | `""` |
| `externalRedis.existingSecretPasswordKey` | Key in the existing secret | `redis-password` |

### Networking

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class | `""` |
| `ingress.hosts` | Ingress hosts | `[{host: n8n.local, paths: [{path: /, pathType: Prefix}]}]` |
| `ingress.tls` | Ingress TLS config | `[]` |
| `testConnection.enabled` | Enable helm test connection pod | `true` |
| `testConnection.image` | Image for the test connection pod | `busybox` |

## Validation

The chart validates your configuration and fails with a clear error message if:

- Invalid `database.type` (must be `sqlite` or `postgresdb`)
- Invalid `runners.mode` (must be `internal` or `external`)
- `webhook.enabled=true` without `worker.replicas > 0`
- `worker.replicas > 0` with `database.type=sqlite`
- `worker.replicas > 0` or `webhook.enabled=true` without Redis configured
- `database.type=postgresdb` without a host
- `database.type=postgresdb` without a password or existing secret
- `database.postgresdb.password` and `database.postgresdb.existingSecret` both set (mutually exclusive)
- `externalRedis.password` and `externalRedis.existingSecret` both set (mutually exclusive)
- `runners.mode=external` without `runners.authToken`
- `persistence.enabled=true` with `worker.replicas > 0` (use S3 for binary data with workers)
- `externalS3.enabled=true` without `host`, `bucketName`, or `bucketRegion`
- `externalS3.enabled=true` without credentials (`accessKey`/`accessSecret` or `existingSecret`)
- `externalS3.accessKey` and `externalS3.existingSecret` both set (mutually exclusive)
- `main.replicas > 1` without `worker.replicas > 0` (multi-main requires PostgreSQL + Redis)
