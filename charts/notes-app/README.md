# notes-app

A three-tier demo application, packaged the way real-world charts are:

```
            ┌──────────── Ingress (optional) ────────────┐
browser ──▶ │ web: nginx  ──/api/──▶  api: FastAPI (x2)  │──▶ postgresql: StatefulSet + PVC
            └────────────────────────────────────────────┘
```

| Component | Kubernetes objects | What it shows |
| --- | --- | --- |
| `web` | Deployment, Service, ConfigMap | nginx config and HTML rendered from values; Service type ClusterIP / NodePort / LoadBalancer |
| `api` | Deployment, Service, ConfigMap, HPA (optional) | `envFrom` a ConfigMap, password from a Secret, liveness/readiness probes, init container that waits for the database, rolling update when config changes |
| `postgresql` | StatefulSet, headless Service, Secret | `volumeClaimTemplates`, generated password that survives `helm upgrade`, or switch to an external database |
| test | Pod with `helm.sh/hook: test` | `helm test` checks web → api → database end to end |

## Install

```bash
helm repo add howest https://howest-mct.github.io/helm-demo
helm repo update
helm install notes howest/notes-app -n notes-demo --create-namespace
helm test notes -n notes-demo
kubectl port-forward svc/notes-notes-app-web 8080:80 -n notes-demo
```

Open <http://localhost:8080> and refresh a few times: the info box shows which API pod answered.

## Customise

Create a `my-values.yaml` and only list what you want to change:

```yaml
web:
  title: "Nathan's Notes"
  accentColor: "#0ea5e9"
  service:
    type: NodePort
    nodePort: 30010        # reachable on http://localhost:30010 with k3d -p "30000-30020:30000-30020@server:0"
api:
  replicaCount: 3
  message: "Hello from my own values file"
postgresql:
  persistence:
    size: 2Gi
```

```bash
helm upgrade --install notes howest/notes-app -n notes-demo -f my-values.yaml
```

Using Ingress on k3d (Traefik is installed by default):

```yaml
ingress:
  enabled: true
  host: notes.localhost
```

Using an external database instead of the bundled PostgreSQL:

```yaml
postgresql:
  enabled: false
externalDatabase:
  host: my-postgres.example.com
  database: notes
  username: notes
  existingSecret: my-db-secret   # Secret with the key "password"
```

Try things out without installing: `helm template notes howest/notes-app -f my-values.yaml`.
`values.schema.json` rejects typos such as `web.service.type: NodePorts` before anything reaches the cluster.

## Values

See [`values.yaml`](values.yaml); every value has a comment. The most used ones:

| Key | Default | Description |
| --- | --- | --- |
| `web.title` | `Howest Notes` | Title of the web page |
| `web.service.type` | `ClusterIP` | `ClusterIP`, `NodePort` or `LoadBalancer` |
| `web.service.nodePort` | `null` | Fixed node port (30000-32767) |
| `api.replicaCount` | `2` | Number of API pods (ignored when autoscaling is on) |
| `api.message` | `Deployed with Helm!` | Shown by `/api/info` |
| `api.image.tag` | `""` | Defaults to the chart's `appVersion` |
| `api.autoscaling.enabled` | `false` | Create a HorizontalPodAutoscaler |
| `postgresql.enabled` | `true` | Run PostgreSQL inside the release |
| `postgresql.auth.password` | `""` | Empty = random, kept across upgrades |
| `postgresql.persistence.enabled` | `true` | PVC via `volumeClaimTemplates`; `false` = emptyDir |
| `ingress.enabled` | `false` | Ingress in front of the web Service |

## Uninstall

```bash
helm uninstall notes -n notes-demo
kubectl delete pvc -l app.kubernetes.io/instance=notes -n notes-demo   # the database volume is kept on purpose
```
