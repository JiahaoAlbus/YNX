# YNX Final Verification Matrix

Status: active verification matrix  
Prepared on: 2026-06-28  
Purpose: define what must be checked before YNX is described as fully
"done" for the current phase

This is not a marketing summary.

This is the practical final-check grid for:

- live public-testnet truth
- runnable local/repo truth
- mock/testnet/provider/legal boundaries
- remaining external blockers

## 1. Verification rule

Before saying YNX is "done" for this phase, each surface should be checked
against:

1. runnable code or live endpoint
2. matching public docs
3. matching pack / manifest references
4. truthful boundary wording
5. explicit blocker list if not fully live

If any of those diverge, the surface is not fully verified yet.

## 2. Surface matrix

| Surface | Current truth | Verification source | Boundary that must remain explicit |
|---|---|---|---|
| Chain / RPC / REST / EVM | live public testnet | `output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md`, live RPC/indexer responses | not mainnet |
| Explorer / indexer | live public testnet | latest snapshot + live runtime alignment | public visibility is real, but some protected forensics remain redacted |
| Bridge | partly live, partly blocked | route readiness board, bridge blocker packet, latest snapshot | do not claim `5/5 full_loop_tested`; current truth is still mixed |
| Web4 policies / sessions | live and tested | `infra/web4-hub/server.test.js`, Web4 docs, OpenAPI | policy protection is real; not a consumer-finance product by itself |
| AI Gateway one-shot chat | live | `POST /ai/chat`, AI health, AI docs | public-testnet intelligence layer, not a general unrestricted agent cloud |
| AI Gateway stream chat | repo-ready; live deployment must be checked directly | `POST /ai/chat/stream`, AI streaming tests, latest snapshot | do not claim live stream until POST endpoint is confirmed online |
| AI settlement | live + tested | AI health, `infra/ai-gateway/server.test.js`, current snapshot | public-testnet settlement only |
| Trace / forensics | implemented and partly protected | capability audit, AI docs, protected action tests | do not imply seizure/freeze authority |
| YNX Card Mock | runnable mock | Web4 tests, `scripts/ynx_card_mock_demo.sh`, card docs | not issuer-backed, not live card rails |
| AI Agent Spending | repo/live hybrid | AI spending docs, Web4 + AI tests, truth matrix | bounded logic exists; real payment/provider rails are not live |
| Provider readiness | ready for review | card provider readiness pack + provider go-live gates | provider-ready for review is not provider go-live ready |
| Grant / outreach materials | ready | grant visibility pack, outreach kit, launchpad pack | cannot imply legal/mainnet/provider completion |
| Compliance boundary | documented | compliance packet, non-custodial boundary, readiness gates | legal entity / contracts / production approvals still external |

## 3. Minimum evidence bundle for final closeout

At final closeout, the following should be rechecked from current state, not
older memory:

- `output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md`
- `output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md`
- `output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md`
- `output/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md`
- `output/card_provider_readiness_pack_latest/MANIFEST.md`
- `output/grant_visibility_pack_latest/MANIFEST.md`
- `output/executive_closeout_pack_latest/MANIFEST.md`

## 4. Current known hard boundaries

The following are still not valid to claim as complete today:

- all bridge routes are full-loop tested
- all bridge routes are automatic-ready
- YNX Card is a live issuer-backed card product
- YNX has completed legal-entity / provider-contract / PCI / production card setup
- YNX is fully mainnet-grade
- all repo-ready runtime features are already deployed live

## 5. Current strongest "done for this phase" wording

The strongest truthful wording today is:

- YNX is a live public-testnet Web4 / AI Agent execution stack
- core chain, Web4, AI settlement, bridge evidence, trace, and YNX Card Mock logic are real
- some surfaces are live now, some are protected, some remain mock/provider-prep, and some still depend on external counterparties

## 6. Best companion docs

- [YNX Current State Board](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_CURRENT_STATE_BOARD_2026_06_28.md)
- [YNX Full-Stack Truth Matrix](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md)
- [YNX Card Provider Go-Live Gates](/Users/huangjiahao/Desktop/YNX/docs/en/YNX_CARD_PROVIDER_GO_LIVE_GATES_2026_06_28.md)
- [Compliance Readiness Packet](/Users/huangjiahao/Desktop/YNX/docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md)
