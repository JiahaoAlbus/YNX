# YNX v2 Web4 API 接口说明

状态：active  
最后更新：2026-05-09

## 1. 权限模型

YNX v2 Web4 API 的执行顺序是：

1. Owner（最高权限）
2. Policy（边界与预算）
3. Session（短期授权）
4. Agent Action（实际动作）

## 2. 请求头

- `content-type: application/json`
- `x-ynx-owner: <owner secret 或 owner id>`（Owner 级操作）
- `x-ynx-session: <session token>`（委托操作）

## 3. 钱包自举

- `POST /web4/wallet/bootstrap`
- `POST /web4/wallet/verify`

## 4. 策略与会话

- `GET /web4/policies`
- `POST /web4/policies`
- `GET /web4/policies/:policy_id`
- `POST /web4/policies/:policy_id/sessions`
- `POST /web4/policies/:policy_id/pause`
- `POST /web4/policies/:policy_id/resume`
- `POST /web4/policies/:policy_id/revoke`

策略支持的关键限制：

- `max_total_spend`
- `max_daily_spend`
- `max_children`
- `replicate_cooldown_sec`
- `allowed_service_hosts`（第三方 API 域名白名单，支持 `*` 和前缀通配）

## 5. 第三方通用授权（任意 API）

- `POST /web4/authorize`
  - 作用：给任何第三方服务做通用放行/拒绝判断
  - 请求体必填：
    - `policy_id`
    - `action`
  - 请求体可选：
    - `amount`（授权通过后要消耗的预算）
    - `resource_host`（目标服务域名，会校验 `allowed_service_hosts`）
    - `resource`（资源标签，例如 `crm/ticket/update`）
    - `context`（追踪元信息）
    - `consume`（`false` 表示只检查不扣减，默认 `true`）
  - 请求头必填：
    - `x-ynx-session`
  - 返回：
    - `ok`、`policy_id`、`session_id`
    - `remaining_ops`、`remaining_spend`、`session_expires_at`

- `POST /web4/authorize/batch`
  - 作用：一次请求里批量授权多步动作，适合多步骤 Agent 流程
  - 请求体必填：
    - `requests`（数组，最多 100 条）
  - `requests` 每一项支持与 `/web4/authorize` 相同字段
  - 语义：
    - 先全量 dry-run 校验（不扣减）
    - 任意一项失败则整批失败，并返回失败项 `index`
    - 全部通过后再顺序真实扣减并授权
  - 成功返回：
    - `ok`、`count`、`items[]`

- `POST /web4/internal/authorize`
  - 与上面相同的决策模型，主要给内部网关使用
  - 配置了 `x-ynx-internal-token` 时会做内部鉴权

## 6. 身份与 Agent

- `GET /web4/identities`
- `POST /web4/identities`
- `GET /web4/agents`
- `POST /web4/agents`
- `GET /web4/agents/:agent_id`
- `POST /web4/agents/:agent_id/self-update`
- `POST /web4/agents/:agent_id/replicate`

## 7. Intent 生命周期

- `GET /web4/intents`
- `POST /web4/intents`
- `GET /web4/intents/:intent_id`
- `POST /web4/intents/:intent_id/claim`
- `POST /web4/intents/:intent_id/challenge`
- `POST /web4/intents/:intent_id/finalize`

## 8. 可观测接口

- `GET /health`
- `GET /web4/overview`
- `GET /web4/stats`
- `GET /web4/audit`

## 9. 常见错误码语义

- `policy_required`
- `policy_action_denied`
- `invalid_session`
- `session_expired`
- `session_spend_exceeded`
- `policy_service_host_denied`
- `replication_limit_reached`
- `replication_cooldown`
