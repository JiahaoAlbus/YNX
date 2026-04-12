# YNX v2 GCP Fullblood Runbook

## Goal

Deploy and keep a three-node YNX v2 public-testnet stack healthy on GCP:

- bootstrap validator + full public services
- rpc follower + full public services
- service follower + full public services

The deployment includes:

- policy enforcement defaults enabled (`AI_ENFORCE_POLICY=1`, `WEB4_ENFORCE_POLICY=1`)
- cluster sync convergence (shared genesis + peer wiring)
- watchdog service installation
- scheduled node backups (systemd timer)

## One-command Deploy

```bash
cd chain
./scripts/v2_gcp_fullblood_deploy.sh <ssh_user> <ssh_key_path> [project_id]
```

Example:

```bash
cd chain
./scripts/v2_gcp_fullblood_deploy.sh huangjiahao ~/.ssh/id_ed25519 ynx-testnet-gcp
```

## Reuse Existing VMs (skip provisioning)

If GCP provisioning is already done, deploy only:

```bash
cd chain
SKIP_GCLOUD_PROVISION=1 \
BOOTSTRAP_IP_OVERRIDE=<bootstrap_ip> \
RPC_IP_OVERRIDE=<rpc_ip> \
SVC_IP_OVERRIDE=<service_ip> \
./scripts/v2_gcp_fullblood_deploy.sh <ssh_user> <ssh_key_path>
```

## Post-deploy Verification

### Cluster sync and critical services

```bash
cd chain
./scripts/v2_cluster_sync_verify.sh <bootstrap_ip> <rpc_ip> <service_ip>
```

### Full smoke verify per host

```bash
cd chain
YNX_PUBLIC_HOST=<host_ip> \
YNX_CHAIN_ID=ynx_9102-1 \
YNX_SMOKE_WRITE=1 \
./scripts/v2_public_testnet_verify.sh
```

## Operations

### Watchdog

Installed as:

- `ynx-v2-watchdog.service`

Check:

```bash
sudo systemctl status ynx-v2-watchdog.service --no-pager
```

### Backups

Installed as:

- `ynx-v2-backup.service`
- `ynx-v2-backup.timer`

Default schedule:

- daily at `03:30` (host local time)

Check:

```bash
sudo systemctl status ynx-v2-backup.timer --no-pager
```

Run one backup immediately:

```bash
sudo systemctl start ynx-v2-backup.service
```

Default backup output:

- `~/.ynx-v2/backups/*.tar.gz`
- `~/.ynx-v2/backups/*.sha256`
- `~/.ynx-v2/backups/*.meta.json`

## DNS Mapping (optional)

If using `ynxweb4.com`, map:

- `rpc.<domain>` -> rpc node IP
- `evm.<domain>` -> rpc node IP
- `evm-ws.<domain>` -> rpc node IP
- `rest.<domain>` -> service node IP
- `faucet.<domain>` -> service node IP
- `indexer.<domain>` -> service node IP
- `explorer.<domain>` -> service node IP
- `ai.<domain>` -> service node IP
- `web4.<domain>` -> service node IP

