# Containerized Operations API

A dependency-free HTTP service packaged as a non-root container. It provides JSON logs, health endpoints and Prometheus metrics. The filesystem is read-only, Linux capabilities are dropped, and Compose limits memory and CPU.

## Run

From this directory, with Docker Desktop running in Linux container mode:

```sh
docker compose config --quiet
docker compose up -d --build --wait
curl http://localhost:8080/
curl http://localhost:8080/healthz
curl http://localhost:8080/metrics
docker compose ps
docker compose logs --tail=30 api
```

Expected: healthy container, HTTP 200, service `ops-api`. Unknown paths return HTTP 404. `/readyz` currently has the same check as `/healthz` because there are no external dependencies.

## Test and troubleshoot

```sh
python -m unittest discover -s tests -v
docker compose stop api
docker compose up -d --wait
docker compose down
```

If the port is occupied, change the host side of `8080:8080`. If a container is unhealthy, inspect logs and health history with `docker inspect`. This uses Python's standard HTTP server for a small lab, not a public production API. Image tags are versioned but not immutable; pin a reviewed digest before production use.

Reference: [Docker Compose services](https://docs.docker.com/reference/compose-file/services/).
