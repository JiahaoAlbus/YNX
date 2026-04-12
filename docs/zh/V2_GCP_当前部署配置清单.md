# YNX v2 GCP 当前部署配置清单

状态：active  
最后更新：2026-04-12

## 目的

这份文档是 YNX v2 公测网在 GCP 上的当前运维基线。  
后续审计、运维、对外对齐，以本清单为准。

## 基线信息

- 仓库基线：`main` @ `c4e9a75`
- 域名：`ynxweb4.com`
- 公测网 Chain ID：`ynx_9102-1`
- EVM Chain ID：`0x238e`

## 当前 GCP 三机拓扑

- Bootstrap 节点：`34.96.134.119`
- RPC 节点：`34.150.93.74`
- Service 节点：`34.92.114.34`

三台机器当前均为：
- `RUNNING`
- 机型：`e2-standard-4`（4 vCPU / 16GB RAM）
- 区域：`asia-east2-b`
- 网络：`default`（仅 IPv4）

## 实时实例配置（live）

- `ynx-v2-bootstrap-1`
  - 内网 IP：`10.170.0.2`
  - 公网 IP：`34.96.134.119`
  - 启动盘：`200GB`，`pd-balanced`，Ubuntu 22.04
  - 删除保护：`false`
  - Shielded VM：`vTPM=true`、完整性监控=true、secure boot=false
- `ynx-v2-rpc-1`
  - 内网 IP：`10.170.0.4`
  - 公网 IP：`34.150.93.74`
  - 启动盘：`80GB`，`pd-standard`，Ubuntu 22.04
  - 删除保护：`false`
  - Shielded VM：`vTPM=true`、完整性监控=true、secure boot=false
- `ynx-v2-service-1`
  - 内网 IP：`10.170.0.5`
  - 公网 IP：`34.92.114.34`
  - 启动盘：`80GB`，`pd-standard`，Ubuntu 22.04
  - 删除保护：`false`
  - Shielded VM：`vTPM=true`、完整性监控=true、secure boot=false

## 公网域名路由

- `rpc.ynxweb4.com` -> `34.150.93.74`
- `evm.ynxweb4.com` -> `34.150.93.74`
- `evm-ws.ynxweb4.com` -> `34.150.93.74`
- `rest.ynxweb4.com` -> `34.92.114.34`
- `grpc.ynxweb4.com` -> `34.92.114.34`
- `faucet.ynxweb4.com` -> `34.92.114.34`
- `indexer.ynxweb4.com` -> `34.92.114.34`
- `explorer.ynxweb4.com` -> `34.92.114.34`
- `ai.ynxweb4.com` -> `34.92.114.34`
- `web4.ynxweb4.com` -> `34.92.114.34`

## 链上描述符实时值（network-descriptor）

- Seed / persistent peer：
  - `4873f5737444f3fb3eced7035e0afc0fc1192110@34.96.134.119:36656`
- 描述符地址：
  - `https://indexer.ynxweb4.com/ynx/network-descriptor`

## 安全开关状态（实时）

- AI Gateway：
  - `enforce_policy=true`
  - `has_web4_authorizer=true`
- Web4 Hub：
  - `enforce_policy=true`
  - `internal_authorizer_enabled=true`

## 部署默认参数（来自脚本）

来源：`chain/scripts/v2_gcp_fullblood_deploy.sh`

- 默认 Billing Account：`01562C-E2CAC9-5704C6`
- Region：`asia-east2`
- Zone：`asia-east2-b`
- 机器规格：`e2-standard-4`
- 系统盘：`80GB`（`pd-standard`）
- 镜像：`ubuntu-2204-lts`

说明：
- 当前现网与脚本默认值有一处差异：bootstrap 启动盘是 `200GB pd-balanced`。

## 公开入口端口

当前部署使用的主要端口：

- SSH：`22`
- P2P / 节点：`36656`、`36657`
- REST / gRPC / EVM：`31317`、`39090`、`38545`、`38546`
- 业务服务：`38080`、`38081`、`38082`、`38090`、`38091`
- HTTPS 网关：`80`、`443`

防火墙规则：
- `ynx-v2-public`（INGRESS，来源 `0.0.0.0/0`）

## 结算与预算（live）

- 项目结算：已启用（`projects/ynx-testnet-gcp` -> `billingAccounts/01562C-E2CAC9-5704C6`）
- 预算 `YNX`：
  - 月预算 HKD `100`
  - 实际支出提醒：50%、90%、100%（另含 25%、75%）
  - `creditTypesTreatment=EXCLUDE_ALL_CREDITS`
- 预算 `YNX-Credit-Guard-Stop`：
  - 月预算 HKD `2300`
  - 实际支出提醒：100%
  - `creditTypesTreatment=EXCLUDE_ALL_CREDITS`

## 快速验收命令

```bash
curl -sS https://rpc.ynxweb4.com/status | jq -r '.result.node_info.network,.result.sync_info.latest_block_height,.result.sync_info.catching_up'
curl -sS https://evm.ynxweb4.com -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' | jq
curl -sS https://faucet.ynxweb4.com/health | jq
curl -sS https://indexer.ynxweb4.com/ynx/overview | jq
curl -sS https://ai.ynxweb4.com/health | jq
curl -sS https://web4.ynxweb4.com/health | jq
```

## 说明

每台实例的 CPU、内存、磁盘实时使用率，需要 SSH 或 `gcloud` 权限直接查询。  
本清单先记录当前已经验证通过的公网行为和部署默认配置。
