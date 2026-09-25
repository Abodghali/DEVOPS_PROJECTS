# Monitoring

Local Compose starts Prometheus and Grafana with a pre-provisioned datasource and dashboard. Log in as `admin` with `GRAFANA_PASSWORD` from the locally generated `.env`. The README lists each project's host ports. Kubernetes dashboards also show node and pod metrics supplied by kube-prometheus-stack. These infrastructure panels are empty in the small Compose setup because it does not run Kubernetes exporters.

For Kubernetes, run `scripts/monitoring.sh` using an explicit context. The script installs kube-prometheus-stack and applies the project's ServiceMonitor, PrometheusRule and dashboard ConfigMap. Open Grafana locally:

```bash
kubectl --context "$KUBE_CONTEXT" -n monitoring port-forward service/monitoring-grafana 3000:80
```

The application exposes `/metrics`, with request counts and duration histograms labelled by service and environment. The environment and namespace dropdowns let you inspect Dev, Staging and Production separately. Counts include health probes. The default rules detect sustained HTTP errors and pod restarts. Project-specific panels cover recovery, review environments or GitLab telemetry.

Prometheus retains seven days in this lab configuration, but its default storage is ephemeral. Application/database PVCs are separate. Configure persistent monitoring storage and remote retention before relying on historical records across monitoring redeployments. Alerts appear in Prometheus/Alertmanager; no email or messaging destination is configured.

For a runner host outside Kubernetes, use the internal platform's `add-runner-metrics.sh` with its private IP. Metrics endpoints should be reachable only from the monitoring network. GitLab pipeline counts represent the last 20 API results per configured project, and duration is the mean of up to five completed pipelines; these are not lifetime totals. The API scrape-health metric must be checked alongside them to avoid interpreting stale data as current.
