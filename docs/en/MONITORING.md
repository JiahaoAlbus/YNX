# YNX Monitoring (v0)

Status: v0  
Last updated: 2026-02-12  
Canonical language: English

## 1. Overview

This stack provides Prometheus scraping plus Grafana dashboards for testnet operations.

## 2. Run

```bash
cd infra/monitoring
docker compose up -d
```

Prometheus: `http://localhost:9090`  
Grafana: `http://localhost:3000`

## 3. Metrics sources

CometBFT metrics:
- Ensure `YNX_PROMETHEUS=1` (default in `testnet_multinode.sh`).
- Each node exposes metrics on its `prometheus_listen_addr` port (default base `26660`).

Indexer metrics:
- The indexer exposes `/metrics` on its service port (default `8081`).

## 4. Targets

Prometheus uses `infra/monitoring/prometheus.yml`.  
For multiple validators, add additional targets for each node’s Prometheus port.

## 5. Grafana

Grafana starts with the default admin login.  
Change the password on first login and configure Prometheus as a data source.
