# YNX v2 Web4 API Reference

Status: Active  
Last updated: 2026-03-07

## 1. Model

YNX v2 Web4 APIs follow sovereignty order:

1. Owner (root authority)
2. Policy (budget + action boundaries)
3. Session (short-lived delegated capability)
4. Agent action (must pass policy/session checks)

## 2. Headers

- `content-type: application/json`
- `x-ynx-owner: <owner secret or owner id>` (owner actions)
- `x-ynx-session: <session token>` (delegated actions)

## 3. Wallet Bootstrap

- `POST /web4/wallet/bootstrap`
  - Creates bootstrap challenge and wallet bootstrap record
- `POST /web4/wallet/verify`
  - Confirms bootstrap with signature-like proof and returns API key

## 4. Policy and Session

- `GET /web4/policies`
- `POST /web4/policies`
  - Creates policy with limits:
    - `max_total_spend`
    - `max_daily_spend`
    - `max_children`
    - `replicate_cooldown_sec`
- `GET /web4/policies/:policy_id`
- `POST /web4/policies/:policy_id/sessions` (owner header required)
- `POST /web4/policies/:policy_id/pause` (owner header required)
- `POST /web4/policies/:policy_id/resume` (owner header required)
- `POST /web4/policies/:policy_id/revoke` (owner header required)

## 5. Identity and Agent

- `GET /web4/identities`
- `POST /web4/identities` (session required when policy enforced)
- `GET /web4/agents`
- `POST /web4/agents` (session required when policy enforced)
- `GET /web4/agents/:agent_id`
- `POST /web4/agents/:agent_id/self-update`
  - Allowed patch fields: `name`, `model`, `endpoint`, `capabilities`
- `POST /web4/agents/:agent_id/replicate`
  - Creates child agent under policy constraints

## 6. Intent Lifecycle

- `GET /web4/intents`
- `POST /web4/intents`
- `GET /web4/intents/:intent_id`
- `POST /web4/intents/:intent_id/claim`
- `POST /web4/intents/:intent_id/challenge`
- `POST /web4/intents/:intent_id/finalize`

## 7. Observability

- `GET /health`
- `GET /web4/overview`
- `GET /web4/stats`
- `GET /web4/audit`

## 8. Error Patterns

Common error strings:

- `policy_required`
- `policy_action_denied`
- `session_required`
- `invalid_session`
- `session_expired`
- `session_spend_exceeded`
- `replication_limit_reached`
- `replication_cooldown`
