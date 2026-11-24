# notes-api

The backend used by the [`notes-app`](../../charts/notes-app) chart: a small FastAPI service that stores notes in PostgreSQL.

| Endpoint | Purpose |
| --- | --- |
| `GET /healthz` | Liveness probe: the process is running |
| `GET /readyz` | Readiness probe: the database answers |
| `GET /api/info` | Which pod answered, version, message from the ConfigMap |
| `GET /api/notes` / `POST /api/notes` / `DELETE /api/notes/{id}` | The notes themselves |

Configuration comes from environment variables: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `APP_MESSAGE`, `APP_VERSION`, `MAX_NOTES`.

The image is built by GitHub Actions and published as `ghcr.io/howest-mct/helm-demo-api:<appVersion>` (linux/amd64 and linux/arm64), with the tag taken from `appVersion` in the chart's `Chart.yaml`.
