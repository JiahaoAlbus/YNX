# YNX v2 Web4 API Reference

Status: Active  
Last updated: 2026-05-09

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
- `x-ynx-api-key: <bootstrap api key>` (wallet-backed policy creation when bootstrap gating is enabled)

## 3. Wallet Bootstrap

- `POST /web4/wallet/bootstrap`
  - Creates bootstrap challenge and wallet bootstrap record
- `POST /web4/wallet/verify`
  - Confirms bootstrap with a real wallet signature over the issued challenge and returns API key
  - bootstrap api keys are single-use for policy creation by default
  - bootstrap challenges and bootstrap api keys expire by default

## 4. Policy and Session

- `GET /web4/policies`
- `POST /web4/policies`
  - When bootstrap gating is enabled, requires `x-ynx-api-key` from a verified wallet bootstrap
  - bootstrap api keys are single-use for policy creation by default
  - expired bootstrap api keys are rejected
  - Creates policy with limits:
    - `max_total_spend`
    - `max_daily_spend`
    - `max_children`
    - `replicate_cooldown_sec`
    - `allowed_service_hosts` (third-party API host allowlist, supports `*` and prefix wildcard)
- `GET /web4/policies/:policy_id`
- `POST /web4/policies/:policy_id/sessions` (owner header required)
- `POST /web4/policies/:policy_id/pause` (owner header required)
- `POST /web4/policies/:policy_id/resume` (owner header required)
- `POST /web4/policies/:policy_id/revoke` (owner header required)

## 5. Third-Party Authorization (Any API)

- `POST /web4/authorize`
  - Purpose: generic allow/deny decision for any external service call
  - Required body fields:
    - `policy_id`
    - `action`
  - Optional body fields:
    - `amount` (spend units to consume if authorized)
    - `resource_host` (target host, checked against `allowed_service_hosts`)
    - `resource` (free-form resource tag, e.g. `crm/ticket/update`)
    - `context` (trace metadata)
    - `consume` (`false` for dry-run check, default `true`)
  - Required header:
    - `x-ynx-session`
  - Returns:
    - `ok`, `policy_id`, `session_id`
    - `remaining_ops`, `remaining_spend`, `session_expires_at`

- `POST /web4/authorize/batch`
  - Purpose: authorize multiple actions in one round trip for multi-step agent workflows
  - Required body field:
    - `requests` (array, max 100 items)
  - Each request item supports the same fields as `/web4/authorize`
  - If any item fails validation, the whole batch returns an error with `index`
  - On success, returns:
    - `ok`, `count`, `items[]`

- `POST /web4/internal/authorize`
  - Same decision model, intended for trusted internal gateways
  - Optional `x-ynx-internal-token` check when configured
## 6. Identity and Agent

- `GET /web4/identities`
- `POST /web4/identities` (session required when policy enforced)
- `GET /web4/agents`
- `POST /web4/agents` (session required when policy enforced)
- `GET /web4/agents/:agent_id`
- `POST /web4/agents/:agent_id/self-update`
  - Allowed patch fields: `name`, `model`, `endpoint`, `capabilities`
- `POST /web4/agents/:agent_id/replicate`
  - Creates child agent under policy constraints

## 7. YNX Card Mock

- `GET /web4/cards`
- `POST /web4/cards` (owner header required)
- `GET /web4/cards/:card_id`
- `POST /web4/cards/:card_id/authorize`
  - Required header:
    - `x-ynx-session`
  - Required body fields:
    - `policy_id`
    - `amount`
  - Typical body fields:
    - `agent_id`
    - `merchant`
    - `mcc`
    - `country`
  - Rules can include:
    - `require_agent`
    - `allowed_agents`
    - `allowed_merchants`
    - `blocked_merchants`
    - `allowed_mccs`
    - `blocked_mccs`
    - `allowed_countries`
    - `blocked_countries`
    - `max_per_txn`
    - `max_daily_spend`
    - `max_total_spend`
- `POST /web4/cards/:card_id/freeze` (owner header required)
- `POST /web4/cards/:card_id/resume` (owner header required)

This is currently a programmable mock-card control layer, not a real issuer
integration.

## 8. Intent Lifecycle

- `GET /web4/intents`
- `POST /web4/intents`
- `GET /web4/intents/:intent_id`
- `POST /web4/intents/:intent_id/claim`
- `POST /web4/intents/:intent_id/challenge`
- `POST /web4/intents/:intent_id/finalize`

## 9. Observability

- `GET /health`
- `GET /web4/overview`
- `GET /web4/stats`
- `GET /web4/audit` — policy-scoped; expect `policy_id` + `x-ynx-session`

## 10. Error Patterns

Common error strings:

- `policy_required`
- `policy_action_denied`
- `session_required`
- `invalid_session`
- `session_expired`
- `session_spend_exceeded`
- `policy_service_host_denied`
- `replication_limit_reached`
- `replication_cooldown`
- `card_inactive`
- `merchant_not_allowed`
- `merchant_blocked`
- `mcc_not_allowed`
- `mcc_blocked`
- `country_not_allowed`
- `country_blocked`
