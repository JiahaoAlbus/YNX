# YNX Card Provider Go-Live Gates

Status: active pre-go-live gate  
Prepared on: 2026-06-28  
Purpose: define the minimum conditions required before YNX Card can move from
mock/provider-readiness into any real sandbox or production provider path

## 1. Current position

YNX Card is currently a programmable mock/control layer.

That is enough to prove:

- rule-based authorization logic
- bounded AI-agent spend control
- explicit approve / decline outcomes
- audit events and reviewability

That is **not** enough to claim:

- real issuer-backed cards
- real PAN/CVV handling
- live processor/network authorization
- production settlement or dispute operations

## 2. Gate model

YNX Card should move through these phases in order:

1. mock logic proven
2. provider sandbox technically mapped
3. legal/compliance ownership assigned
4. security and operational controls proven
5. limited provider pilot
6. broader production rollout

Do not skip from phase 1 to phase 5.

## 3. Mandatory gates before provider sandbox

Before even a real sandbox integration, YNX should have:

- legal entity and signatory authority
- named owner for provider contracting
- named owner for KYC/KYB/AML responsibility split
- named owner for incident response and customer support
- provider API contract review
- provider event/reference-id mapping design
- secure storage model for provider credentials
- explicit mock/sandbox/production environment separation

## 4. Mandatory gates before limited real pilot

Before a limited real pilot, YNX should also have:

- documented authorization-decision mapping between YNX rules and provider rails
- production-grade audit log retention plan
- reconciliation ledger and exception-handling workflow
- refund / reversal / chargeback operating workflow
- sanctions / fraud / dispute escalation path
- clear PCI scope decision
- reviewed privacy/data-processing boundaries
- operator runbook for freeze / resume / incident handling
- finance/treasury ownership for settlement mismatches

## 5. Mandatory gates before broader production claims

Before broader production claims, YNX should also have:

- external security review or equivalent provider-required review
- durable persistence beyond demo-grade local/json assumptions
- rollback and incident-response drills
- provider SLA / support model agreed
- legal wording updated across docs and website
- public language no longer dependent on "mock-only" explanations

## 6. Hard no-go conditions

YNX Card must **not** be described as live-go-ready if any of these remain true:

- no legal entity exists
- no signed provider relationship exists
- no clear KYC/KYB/AML ownership exists
- no PCI/data-scope decision exists
- no reconciliation/dispute ownership exists
- no provider event-id mapping exists
- no secure credential storage exists
- no incident-response owner exists

## 7. Current YNX status against these gates

Current truthful status:

- phase 1: yes, mock logic proven
- phase 2: partly prepared through provider-readiness packet and API/control mapping
- phase 3: not complete
- phase 4: not complete
- phase 5: not started
- phase 6: not started

So the correct current external wording is:

- YNX Card is provider-ready for review
- YNX Card is not provider go-live ready

## 8. Best companion artifacts

- [YNX Card Provider Readiness Packet](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_CARD_PROVIDER_READINESS_PACKET_2026_06_28.md)
- [YNX Card Mock](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_CARD_MOCK.md)
- [AI Agent Spending](/Users/huangjiahao/Desktop/YNX/docs/en/AI_AGENT_SPENDING.md)
- [Compliance Readiness Packet](/Users/huangjiahao/Desktop/YNX/docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md)
- [YNX Current State Board](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_CURRENT_STATE_BOARD_2026_06_28.md)
