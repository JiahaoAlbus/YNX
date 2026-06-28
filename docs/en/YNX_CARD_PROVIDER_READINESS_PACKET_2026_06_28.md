# YNX Card Provider Readiness Packet

Status: active pre-provider packet  
Prepared on: 2026-06-28  
Audience: issuer, program manager, processor, compliance partner, banking partner, or card-enablement provider

## 1. What YNX is asking a provider to understand

YNX is not presenting a finished live card program today.

YNX is presenting a programmable spending-control foundation that already
proves:

- owner-scoped control
- policy-bounded agent permissions
- card-like spend evaluation
- explicit approve / decline decisions
- auditable event history

The provider-side ask is not "trust a mock and go live tomorrow."

The provider-side ask is:

- review the current control-plane logic
- confirm what a real provider integration would need
- map YNX controls to the provider's issuer / processor model
- identify legal, compliance, PCI, settlement, and operational requirements

## 2. What exists now

Current YNX Card Mock capabilities:

- create mock card under an owner policy
- view one card and recent authorizations
- authorize one spend attempt against rule set
- freeze card
- resume card

Current rule shapes already implemented:

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

Current audit events already implemented:

- `card.created`
- `card.authorized`
- `card.declined`
- `card.settled`
- `card.reversed`
- `card.refunded`
- `card.frozen`
- `card.resumed`

Current API surfaces:

- `POST /web4/cards`
- `GET /web4/cards`
- `GET /web4/cards/:card_id`
- `POST /web4/cards/:card_id/authorize`
- `POST /web4/cards/:card_id/settle`
- `POST /web4/cards/:card_id/reverse`
- `POST /web4/cards/:card_id/refund`
- `POST /web4/cards/:card_id/freeze`
- `POST /web4/cards/:card_id/resume`

Primary evidence:

- [YNX Card Mock](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_CARD_MOCK.md)
- [YNX Card Mock Demo](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_CARD_MOCK_DEMO.md)
- [AI Agent Spending](/Users/huangjiahao/Desktop/YNX/docs/en/AI_AGENT_SPENDING.md)
- [YNX Card Provider Go-Live Gates](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_CARD_PROVIDER_GO_LIVE_GATES_2026_06_28.md)
- [YNX v2 Web4 API](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_v2_WEB4_API.md)
- [Web4 OpenAPI](/Users/huangjiahao/Desktop/YNX/infra/openapi/ynx-v2-web4.yaml)

## 3. What does not exist yet

YNX does **not** currently claim:

- live issued cards
- live PAN / CVV handling
- PCI card-data production environment
- live authorization routing into Visa / Mastercard / issuer processor rails
- provider-grade settlement / reconciliation / chargeback / refund operations
- YNX-operated consumer KYC as a base protocol business

This packet is intentionally pre-provider and pre-production.

## 4. Integration model YNX is aiming for

YNX wants the provider relationship to preserve a clear split:

- YNX control plane:
  - wallet / policy / session / agent logic
  - programmable spend constraints
  - audit trail
  - operator review and accountability surfaces
- provider / issuer side:
  - issuance
  - regulated card program operations
  - KYC / KYB / sanctions checks if required
  - network connectivity
  - settlement / reconciliation / dispute operations
  - PCI-scoped data handling

That means YNX should remain the programmable authorization and audit layer,
not become a disguised custody or issuer operator by default.

## 5. Provider capability mapping

| YNX need | Current YNX status | Real provider responsibility later |
|---|---|---|
| programmable spend rules | implemented in mock | expose hooks or authorization controls that can enforce or respect external rules |
| agent-bounded authorization | implemented in mock | allow mapped cardholder / business / delegate models without breaking issuer controls |
| merchant / MCC / country filters | implemented in mock | map to processor/issuer controls or pre-auth policy engine |
| per-txn / daily / total limits | implemented in mock | enforce through issuer limits, shadow ledger, or provider-authorized controls |
| audit trail | implemented in mock | support reference ids, event reasons, and reconciliation anchors |
| freeze / resume | implemented in mock | support provider-side suspend/resume controls |
| card issuance | not implemented | provider responsibility |
| PAN/CVV lifecycle | not implemented | provider responsibility in PCI scope |
| KYC/KYB/AML | not implemented by YNX base protocol | regulated partner responsibility unless legal structure changes |
| settlement / disputes / refunds | mock ledger now implemented; provider-grade ops not implemented | provider responsibility plus agreed YNX/operator workflow |

## 6. Technical requirements before a real integration

Before moving beyond mock, YNX would still need:

- provider API contract review
- auth model for provider APIs
- provider-side idempotency and reference mapping
- event webhooks or polling model
- secure storage model for provider credentials
- provider-grade reconciliation ledger and exception handling
- refund / reversal / dispute / incident workflows
- audit mapping from YNX `card.authorized` / `card.declined` / `card.settled` / `card.refunded` events to provider event ids

## 7. Security boundary YNX wants to preserve

YNX wants to preserve these invariants:

- no production private keys or provider credentials in public demos
- no misleading "live card" language before provider go-live
- no PAN / CVV / cardholder-data storage in the current mock layer
- no automatic expansion from protocol logic into consumer KYC business by default
- explicit separation between:
  - testnet
  - mock
  - sandbox provider integration
  - production provider integration

## 8. Compliance and legal prerequisites

Before any real provider go-live, YNX would still need:

- legal entity and signing authority
- counsel-reviewed operating scope
- partner allocation of KYC / KYB / sanctions / AML responsibilities
- data-processing and privacy review
- PCI scope decision and control ownership
- incident-response and customer-support ownership model
- settlement / treasury / reserve / reconciliation ownership model

Supporting boundaries:

- [Compliance Readiness Packet](/Users/huangjiahao/Desktop/YNX/docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md)
- [Non-Custodial Business and Compliance Boundary](/Users/huangjiahao/Desktop/YNX/docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md)
- [Mainnet and Industry Readiness Gates](/Users/huangjiahao/Desktop/YNX/docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md)

## 9. Questions a provider can answer next

1. Can the provider support programmable authorization controls at the granularity YNX wants?
2. Can the provider expose MCC / merchant / country / amount constraints directly, or should YNX operate a shadow pre-authorization layer?
3. What identifiers should YNX persist to reconcile provider authorizations with YNX audit events?
4. What KYB / contract / compliance prerequisites are required before sandbox access?
5. Can the provider support delegated business / AI-agent spending under enterprise controls?
6. What PCI or cardholder-data scope would YNX inherit, if any, under the proposed integration?

## 10. Best next step

The best next step is not public launch.

The best next step is a scoped provider conversation using this packet plus:

- current capability audit
- current truth matrix
- current card mock demo evidence
- current provider go-live gates
- current compliance boundary docs

That is the right bridge between "mock logic proven" and "real provider integration planned responsibly."
