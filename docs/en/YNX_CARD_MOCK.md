# YNX Card Mock

Status: active mock surface  
Last updated: 2026-06-27

## 1. What this is

YNX Card Mock is the current programmable card-control layer for YNX.

It is not a real bank card, not a live issuer integration, and not a hidden
custody product. It is a mock control plane that proves the logic needed for
future compliant card-program integrations:

- mock card creation under an owner policy
- bounded agent spending authorization
- merchant / MCC / country / per-txn / daily / total rule evaluation
- explicit approve or decline decision
- audit logs for every create, authorize, decline, freeze, and resume action

This means YNX can already demonstrate the important part of the idea:

- a user or operator defines spending rules
- an AI agent is granted limited permission
- a spend attempt is evaluated against policy + session + card rules
- the system records why the payment was approved or rejected

## 2. Current model

YNX Card Mock sits on top of the existing Web4 control plane:

1. owner
2. policy
3. session
4. card authorization attempt

The spend path is intentionally layered:

- the session must have `card.authorize`
- the session and policy spend ceilings must allow the attempt
- the card mock rules must allow the merchant / MCC / country / amount
- the decision is then recorded in audit and authorization history

This makes the card layer consistent with the rest of YNX instead of becoming a
separate one-off demo.

## 3. What works now

Current Web4 Hub card-mock capabilities:

- `POST /web4/cards`
- `GET /web4/cards`
- `GET /web4/cards/:card_id`
- `POST /web4/cards/:card_id/authorize`
- `POST /web4/cards/:card_id/freeze`
- `POST /web4/cards/:card_id/resume`

Current rule controls:

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

Current audit/event outputs:

- `card.created`
- `card.authorized`
- `card.declined`
- `card.frozen`
- `card.resumed`

## 4. What this is not

YNX Card Mock does **not** currently mean:

- real issued cards
- real card networks
- real settlement with Visa / Mastercard / issuer processors
- real KYC / KYB
- real chargeback handling
- real stored PAN / CVV / PCI cardholder data environment

So the correct external wording is:

- YNX already has a programmable mock card-control layer
- YNX does not yet have a live compliant issuer integration

## 5. Why this matters

This is useful because the core innovation for YNX Card is not “a pretty card
UI.” The core innovation is a programmable spending-control layer for Web4
wallets and AI agents.

That means the project direction is:

- not just virtual cards
- but policy-bounded, auditable, agent-usable spending

## 6. Future real-provider path

To connect YNX Card Mock to a real compliant provider later, YNX will still
need:

- legal entity readiness
- issuer / program-manager relationship
- KYC / KYB / sanctions / AML workflow
- provider API credentials and operational contracts
- secure PCI-scoped card-data handling design
- production reconciliation, dispute, refund, and incident workflows

The mock surface is intentionally the pre-provider foundation for that future
integration, not a fake substitute for it.
