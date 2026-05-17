# YNX Monitoring And Public Uptime

Status: active  
Last updated: 2026-05-17  
Canonical language: English

## 1. Overview

YNX monitoring has two layers:

- local operator monitoring: Prometheus and Grafana for node/indexer metrics;
- public uptime monitoring: HTTPS probes for the website, RPC, EVM, REST, Faucet, Indexer, Explorer, AI Gateway, and Web4 Hub.

## 2. Public uptime probe

Run a single probe:

```bash
scripts/public_uptime_slo_probe.sh --once
```

Run continuously:

```bash
CHECK_INTERVAL_SEC=60 \
ALERT_WEBHOOK_URL="https://your-alert-webhook" \
scripts/public_uptime_slo_probe.sh
```

Outputs:

- `output/public_uptime_slo/latest.json`
- `output/public_uptime_slo/samples.jsonl`
- `output/public_uptime_slo/LATEST_REPORT.md`

Mainnet-candidate target:

- 7-day public endpoint availability >= `99.5%`;
- P95 public endpoint latency < `5s`;
- no repeated offline window without alert delivery.

## 3. Launch-grade gate monitor

Run:

```bash
scripts/testnet_launch_grade_monitor.sh --once
```

Continuous mode:

```bash
CHECK_INTERVAL_SEC=300 \
ALERT_WEBHOOK_URL="https://your-alert-webhook" \
scripts/testnet_launch_grade_monitor.sh
```

## 4. Local Prometheus/Grafana

```bash
cd infra/monitoring
docker compose up -d
```

Prometheus: `http://localhost:9090`  
Grafana: `http://localhost:3000`

## 5. Metrics sources

CometBFT metrics:
- Ensure `YNX_PROMETHEUS=1` (default in `testnet_multinode.sh`).
- Each node exposes metrics on its `prometheus_listen_addr` port (default base `26660`).

Indexer metrics:
- The indexer exposes `/metrics` on its service port (default `8081`).

## 6. Targets

Prometheus uses `infra/monitoring/prometheus.yml`.  
For multiple validators, add additional targets for each node’s Prometheus port.

## 7. Grafana

Grafana starts with the default admin login.  
Change the password on first login and configure Prometheus as a data source.

## 8. Operational rule

Website status must reflect live probe state. If any core public endpoint is repeatedly offline or times out, public wording must remain `public testnet` and must not say `production`, `mainnet-candidate`, or `institution-ready`.
