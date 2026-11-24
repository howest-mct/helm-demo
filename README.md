# Howest Helm demo charts

Helm chart repository used in the **Containers & Orchestration** Kubernetes labs at Howest MCT.
The charts are published with GitHub Actions and GitHub Pages:

```bash
helm repo add howest https://howest-mct.github.io/helm-demo
helm repo update
helm search repo howest
```

## Charts

| Chart | Level | What you learn from it |
| --- | --- | --- |
| [`example-v2`](charts/example-v2) | Basic | The structure of a chart: `Chart.yaml`, `values.yaml`, templates, `_helpers.tpl`, `NOTES.txt` and a `helm test`. Deploys a single nginx Deployment. |
| [`notes-app`](charts/notes-app) | Realistic | A three-tier app (nginx front-end, FastAPI backend, PostgreSQL) with ConfigMaps, Secrets, a StatefulSet with a PVC, probes, an init container, optional Ingress and HPA, a values schema and an end-to-end `helm test`. |

Start with `example-v2` to read a chart from top to bottom, then look at `notes-app` to see how the same building blocks scale up to an application with several components.

```bash
helm install notes howest/notes-app -n notes-demo --create-namespace
helm test notes -n notes-demo
kubectl port-forward svc/notes-notes-app-web 8080:80 -n notes-demo
```

## Repository layout

```
.
├── apps/notes-api/          Source of the backend image used by notes-app
├── charts/
│   ├── example-v2/          Basic example chart
│   └── notes-app/           Realistic multi-component chart
├── .github/workflows/
│   ├── lint-test.yaml       On pull requests: ct lint + install on a kind cluster + helm test
│   └── release.yaml         On main: build ghcr.io/howest-mct/helm-demo-api, release charts
├── ct.yaml                  chart-testing configuration
└── cr.yaml                  chart-releaser configuration
```

## How publishing works

1. Change a chart and **bump its `version`** in `Chart.yaml` (chart-testing fails the pull request otherwise).
2. Open a pull request: the chart is linted, installed on a throwaway kind cluster and tested with `helm test`.
3. Merge to `main`: the release workflow builds and pushes the API image, packages every chart with a new version, attaches the `.tgz` to a GitHub release and updates `index.yaml` on the `gh-pages` branch.
4. `helm repo update` picks up the new version.

Want your own chart repository? Fork or copy this repository, enable GitHub Pages on the `gh-pages` branch and replace the charts with your own. See the [chart-releaser action](https://github.com/helm/chart-releaser-action) for details.
