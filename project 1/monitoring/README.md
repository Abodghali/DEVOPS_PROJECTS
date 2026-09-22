# API Monitoring and Incident Drill

Prometheus scrapes a dedicated copy of the API every 15 seconds and keeps seven days of data in a named volume. The `OpsApiDown` rule becomes firing after a failed target has persisted for one minute. This lab displays alerts in Prometheus; external notification routing is not configured.

## Run

```sh
docker compose up -d --build
docker compose run --rm --no-deps --entrypoint promtool prometheus check config /etc/prometheus/prometheus.yml
```

Open `http://localhost:9090`. Check Targets, then query:

```promql
up{job="ops-api"}
rate(ops_requests_total[5m])
ops_uptime_seconds
```

Requests include monitoring and health probes, so the rate is not solely user traffic.

## Incident runbook

1. Run `docker compose stop api` to simulate an outage.
2. Within roughly 90 seconds, verify `OpsApiDown` is firing in Alerts.
3. Collect `docker compose ps -a` and `docker compose logs --tail=50 api`.
4. Restart with `docker compose start api`; verify the target returns to 1 and the alert clears.
5. Record timestamps, evidence, root cause and recovery in your incident notes.

Stop with `docker compose down`. Metrics remain in the named volume; `docker compose down -v` also deletes this lab's stored metrics.
