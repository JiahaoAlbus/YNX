# YNX Card Mock Demo

Status: active  
Last updated: 2026-06-27

## 1. What this demo proves

This demo proves that YNX Card is already more than a static concept page.

It shows a complete mock control loop:

- wallet bootstrap
- wallet signature verification
- bootstrap-backed policy creation
- session delegation
- bounded agent creation
- YNX Card Mock creation
- approved spend inside rules
- mock settlement against the approved authorization
- mock reversal against the remaining authorization hold
- mock refund against the settled amount
- declined spend outside rules
- audit evidence for authorization and reconciliation outcomes

So the point is not “fake card UI.” The point is that YNX already has a
programmable spending-control surface for Web4 wallets and AI agents.

## 2. Run locally

From the repository root:

```bash
./scripts/ynx_card_mock_demo.sh
```

The script starts a temporary local Web4 Hub by default and writes JSON
evidence under:

```text
output/ynx_card_demo/<run-id>/
```

## 3. What the script does

1. creates a demo wallet
2. requests wallet bootstrap
3. signs the bootstrap challenge
4. verifies the wallet bootstrap
5. creates a wallet-backed policy
6. issues a bounded session
7. creates a bounded agent
8. creates a YNX Card Mock tied to the same policy
9. approves a valid spend attempt
10. records a mock settlement
11. records a mock reversal
12. records a mock refund
13. declines an invalid spend attempt
14. fetches card detail and audit records

## 4. Run against an existing Web4 service

```bash
YNX_CARD_DEMO_USE_EXISTING=1 \
WEB4_URL=https://web4.ynxweb4.com \
./scripts/ynx_card_mock_demo.sh
```

Use this only against environments where writing demo test data is acceptable.

## 5. Boundary

This demo is intentionally mock-only:

- no real card rails
- no live issuer
- no real user funds
- no PCI cardholder data flow

It is a programmable control proof, not a claim of live compliant card
issuance.
