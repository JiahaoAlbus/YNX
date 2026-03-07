# YNX v2 Web4 API 接口说明

状态：active  
最后更新：2026-03-07

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

## 5. 身份与 Agent

- `GET /web4/identities`
- `POST /web4/identities`
- `GET /web4/agents`
- `POST /web4/agents`
- `GET /web4/agents/:agent_id`
- `POST /web4/agents/:agent_id/self-update`
- `POST /web4/agents/:agent_id/replicate`

## 6. Intent 生命周期

- `GET /web4/intents`
- `POST /web4/intents`
- `GET /web4/intents/:intent_id`
- `POST /web4/intents/:intent_id/claim`
- `POST /web4/intents/:intent_id/challenge`
- `POST /web4/intents/:intent_id/finalize`

## 7. 可观测接口

- `GET /health`
- `GET /web4/overview`
- `GET /web4/stats`
- `GET /web4/audit`

## 8. 常见错误码语义

- `policy_required`
- `policy_action_denied`
- `invalid_session`
- `session_expired`
- `session_spend_exceeded`
- `replication_limit_reached`
- `replication_cooldown`
