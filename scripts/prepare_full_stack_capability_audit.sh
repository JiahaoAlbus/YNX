#!/usr/bin/env bash
set -euo pipefail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-snapshot)
      SKIP_SNAPSHOT=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_full_stack_capability_audit.sh [--skip-snapshot]

Generate a machine-readable and human-readable YNX capability audit covering:
  - runnable now vs mock vs testnet vs provider-dependent surfaces
  - security and funds-safety boundary status
  - compliance boundary
  - top current risks and next gates
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

OUTPUT_BASE="${REPO_ROOT}/output"
LATEST_DIR="${OUTPUT_BASE}/full_stack_capability_audit_latest"
STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
OUTPUT_DIR="${OUTPUT_BASE}/full_stack_capability_audit_${STAMP_LOCAL}"
SNAPSHOT_JSON="${OUTPUT_BASE}/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.json"
ALIGNMENT_JSON="${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json"

mkdir -p "${OUTPUT_DIR}"

if [[ "${SKIP_SNAPSHOT:-0}" != "1" ]]; then
  bash ./scripts/current_full_stack_status_snapshot.sh >/dev/null
fi

[[ -f "${SNAPSHOT_JSON}" ]] || {
  echo "missing snapshot json: ${SNAPSHOT_JSON}" >&2
  exit 1
}

bridge_routes="$(jq -r '.live.bridge.summary.routes // 0' "${SNAPSHOT_JSON}")"
bridge_full_loop_tested="$(jq -r '.live.bridge.summary.full_loop_tested // 0' "${SNAPSHOT_JSON}")"
bridge_deposit_tested="$(jq -r '.live.bridge.summary.deposit_tested // 0' "${SNAPSHOT_JSON}")"
bridge_automatic="$(jq -r '.live.bridge.summary.automatic_loop_ready // 0' "${SNAPSHOT_JSON}")"
ai_forensics_review_visible="$(jq -r '.alignment.ai_runtime_visibility.forensics_review_breakdown_exposed_live // false' "${SNAPSHOT_JSON}")"
ai_forensics_escalation_visible="$(jq -r '.alignment.ai_runtime_visibility.forensics_escalation_breakdown_exposed_live // false' "${SNAPSHOT_JSON}")"
rpc_chain_id="$(jq -r '.live.rpc.chain_id // ""' "${SNAPSHOT_JSON}")"
rpc_height="$(jq -r '.live.rpc.height // ""' "${SNAPSHOT_JSON}")"
indexer_ok="$(jq -r '.live.indexer.ok // false' "${SNAPSHOT_JSON}")"
ai_ok="$(jq -r '.live.ai.ok // false' "${SNAPSHOT_JSON}")"
web4_ok="$(jq -r '.live.web4.ok // false' "${SNAPSHOT_JSON}")"
website_ai_http="$(jq -r '.live.public_surfaces.website_ai_http // ""' "${SNAPSHOT_JSON}")"

alignment_status="UNKNOWN"
if [[ -f "${ALIGNMENT_JSON}" ]]; then
  alignment_status="$(jq -r '.overall_status // "UNKNOWN"' "${ALIGNMENT_JSON}")"
fi

jq -n \
  --arg generated_at_utc "${NOW_UTC}" \
  --arg snapshot_json "output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.json" \
  --arg alignment_json "output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" \
  --arg rpc_chain_id "${rpc_chain_id}" \
  --arg rpc_height "${rpc_height}" \
  --argjson indexer_ok "$(printf '%s' "${indexer_ok}")" \
  --argjson ai_ok "$(printf '%s' "${ai_ok}")" \
  --argjson web4_ok "$(printf '%s' "${web4_ok}")" \
  --arg website_ai_http "${website_ai_http}" \
  --arg alignment_status "${alignment_status}" \
  --arg bridge_routes "${bridge_routes}" \
  --arg bridge_full_loop_tested "${bridge_full_loop_tested}" \
  --arg bridge_deposit_tested "${bridge_deposit_tested}" \
  --arg bridge_automatic "${bridge_automatic}" \
  --argjson ai_forensics_review_visible "$(printf '%s' "${ai_forensics_review_visible}")" \
  --argjson ai_forensics_escalation_visible "$(printf '%s' "${ai_forensics_escalation_visible}")" \
  '{
    generated_at_utc: $generated_at_utc,
    evidence: {
      snapshot_json: $snapshot_json,
      alignment_json: $alignment_json,
      truth_matrix_en: "docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md",
      truth_matrix_zh: "docs/zh/YNX_全栈真相矩阵_2026_06_27.md",
      current_status_en: "docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md",
      current_status_zh: "docs/zh/当前全链状态与对齐快照_2026_06_27.md",
      card_mock_doc_en: "docs/en/YNX_CARD_MOCK.md",
      agent_spending_doc_en: "docs/en/AI_AGENT_SPENDING.md",
      compliance_doc_en: "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md"
    },
    live_runtime: {
      chain_id: $rpc_chain_id,
      height: $rpc_height,
      indexer_ok: $indexer_ok,
      ai_ok: $ai_ok,
      web4_ok: $web4_ok,
      website_ai_http: $website_ai_http,
      alignment_status: $alignment_status
    },
    capability_matrix: [
      {
        id: "chain_rpc",
        surface: "Chain / RPC",
        state_class: "live_public_testnet",
        state_label: "runnable_live_public_testnet",
        summary: "Public YNX chain and RPC are online.",
        proof: ["https://rpc.ynxweb4.com/status", "docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md"],
        security_boundary: "public testnet only; not mainnet-grade final operational posture",
        unsafe_claims: ["mainnet-candidate", "institution-ready"],
        next_requirements: ["validator redundancy", "production durability", "external audit"]
      },
      {
        id: "web4_control_plane",
        surface: "Web4 policy / session / agents",
        state_class: "local_and_live",
        state_label: "runnable_local_and_live",
        summary: "Wallet bootstrap, policy/session delegation, and protected actions are implemented and deployed.",
        proof: ["infra/openapi/ynx-v2-web4.yaml", "docs/en/YNX_v2_WEB4_API.md", "https://web4.ynxweb4.com/ready"],
        security_boundary: "protected write path; not a public open-mutation API",
        unsafe_claims: ["custody", "issuer authorization", "anonymous unrestricted writes"],
        next_requirements: ["more hardening", "provider integrations where needed"]
      },
      {
        id: "ai_settlement",
        surface: "AI settlement / jobs / vaults",
        state_class: "local_and_live",
        state_label: "runnable_local_and_live_public_testnet",
        summary: "AI settlement loop is live with policy enforcement and on-chain settlement readiness.",
        proof: ["docs/en/YNX_v2_AI_SETTLEMENT_API.md", "docs/en/AI_WEB4_OFFICIAL_DEMO.md", "https://ai.ynxweb4.com/health"],
        security_boundary: "policy-bounded testnet execution; not production financial infrastructure",
        unsafe_claims: ["production financial network", "fully mature compliance stack"],
        next_requirements: ["durable persistence", "richer live telemetry", "legal and audit maturity"]
      },
      {
        id: "ai_agent_spending",
        surface: "AI agent spending",
        state_class: "mixed_partial_live",
        state_label: "partly_live_through_testnet_rails",
        summary: "Bounded machine spending model exists and can be demonstrated through settlement rails.",
        proof: ["docs/en/AI_AGENT_SPENDING.md", "scripts/ai_web4_settlement_demo.sh"],
        security_boundary: "bounded and policy-scoped; not unlimited autonomous spend",
        unsafe_claims: ["unlimited autonomous agent spending", "live issuer-backed card spend"],
        next_requirements: ["provider spend rails", "legal/compliance review", "production controls"]
      },
      {
        id: "trace_forensics",
        surface: "Trace / accountability / forensics",
        state_class: "implemented_protected",
        state_label: "implemented_with_protected_access",
        summary: "Lot lineage, comparative taint, evidence chains, and protected case workflows are implemented.",
        proof: ["docs/en/ACCOUNTABILITY_FORENSICS_ENGINE.md", "infra/openapi/ynx-v2-ai.yaml", "infra/indexer/server.test.js", "infra/ai-gateway/server.test.js"],
        security_boundary: "observation and accountability only; not self-help seizure authority",
        unsafe_claims: ["universal multi-chain forensic platform", "private seizure authority"],
        next_requirements: ["more label providers", "more detectors", "stronger persistence"]
      },
      {
        id: "public_trace_preview",
        surface: "Public explorer trace preview",
        state_class: "live_public_testnet",
        state_label: "live_public_redacted_preview",
        summary: "Public explorer exposes redacted trace previews while exact lineage details remain protected.",
        proof: ["docs/en/EXPLORER.md", "https://explorer.ynxweb4.com/"],
        security_boundary: "redacted public preview only",
        unsafe_claims: ["public full lineage", "public exact provenance anchors"],
        next_requirements: ["UX polish while preserving redaction"]
      },
      {
        id: "bridge_routes",
        surface: "Bridge routes",
        state_class: "live_public_testnet_mixed",
        state_label: "live_public_with_mixed_route_maturity",
        summary: ("Current public bridge truth is " + $bridge_full_loop_tested + "/" + $bridge_routes + " full_loop_tested, " + $bridge_deposit_tested + "/" + $bridge_routes + " deposit_tested, and " + $bridge_automatic + "/" + $bridge_routes + " automatic."),
        proof: ["https://rpc.ynxweb4.com/bridge/route-readiness", "output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md"],
        security_boundary: "public testnet bridge evidence; route completion is uneven",
        unsafe_claims: ["5/5 full-loop-tested", "all routes automatic"],
        next_requirements: ["Sepolia signer loading", "BNB testnet lockbox deployment and signer configuration"]
      },
      {
        id: "card_mock",
        surface: "YNX Card Mock",
        state_class: "runnable_mock",
        state_label: "mock_logic_complete_not_issuer_backed",
        summary: "Programmable card-control logic is implemented as a mock control plane with policy, auth, approval/denial, and audit records.",
        proof: ["docs/en/YNX_CARD_MOCK.md", "docs/en/YNX_CARD_MOCK_DEMO.md", "scripts/ynx_card_mock_demo.sh", "infra/web4-hub/server.test.js"],
        security_boundary: "mock control plane only; not real card issuance or live settlement",
        unsafe_claims: ["licensed card program", "live bank-card issuance", "production card network"],
        next_requirements: ["issuer/processor integration", "KYC/compliance/legal entity", "provider contracts and credentials"]
      },
      {
        id: "docs_grant_outreach",
        surface: "Docs / grant / outreach",
        state_class: "repo_ready",
        state_label: "ready_for_review_and_adaptation",
        summary: "Grant, outreach, diligence, truth matrix, and closeout packs are prepared and packaged.",
        proof: ["docs/en/GRANT_APPLICATION_KIT_2026_06_27.md", "docs/en/X_TELEGRAM_OUTREACH_KIT_2026_06_27.md", "output/grant_visibility_pack_latest/MANIFEST.md", "output/executive_closeout_pack_latest/MANIFEST.md"],
        security_boundary: "prepared content only; no automatic public posting or submission",
        unsafe_claims: ["officially submitted grant", "officially published X or Telegram posts"],
        next_requirements: ["target-specific tailoring", "manual founder approval before submission/publication"]
      }
    ],
    security_status: {
      overall: "guarded_testnet_scope",
      strengths: [
        "policy-scoped writes",
        "public-versus-protected trace boundary",
        "bounded mock card authorization model",
        "truthful separation between mock, testnet, and provider-dependent layers"
      ],
      current_gaps: [
        "live AI health does not yet expose forensic-case review counters",
        "bridge route completion is uneven",
        "real issuer/provider integrations are not present"
      ]
    },
    funds_safety_status: {
      overall: "safe_by_default_for_current_scope",
      guarantees_now: [
        "no claim of live custody",
        "no real card issuance path in current mock surface",
        "no production issuer credentials required for current card demo",
        "bridge blockers are configuration-scoped and explicitly recorded"
      ],
      still_not_guaranteed: [
        "mainnet funds safety under real value conditions",
        "provider-side settlement guarantees",
        "institutional operational controls"
      ]
    },
    compliance_boundary: {
      current_position: "non_custodial_public_testnet_infrastructure",
      docs: [
        "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md",
        "docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md",
        "docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md"
      ],
      do_not_imply: [
        "finished legal sign-off",
        "completed external audit coverage",
        "licensed redemption or custody",
        "issuer-backed production card launch"
      ]
    },
    top_risks: [
      {
        id: "bridge_route_gap",
        severity: "high",
        summary: "Bridge route maturity is still 2/5 full-loop-tested and 2/5 automatic.",
        mitigation_reference: "output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md"
      },
      {
        id: "ai_visibility_gap",
        severity: "medium",
        summary: "Live AI health does not yet expose the newer forensic workflow counters present in local code.",
        mitigation_reference: "output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md"
      },
      {
        id: "provider_dependency_gap",
        severity: "high",
        summary: "YNX Card and broader programmable spend rails remain pre-provider and pre-legal-entity.",
        mitigation_reference: "docs/en/YNX_CARD_MOCK.md"
      }
    ],
    next_gates: [
      "complete remaining bridge configuration blockers",
      "improve live AI observability to reflect current forensic workflow counters",
      "keep YNX Card positioned as mock control logic until provider/legal prerequisites are real",
      "continue external-facing materials only within truthful public-testnet scope"
    ]
  }' > "${OUTPUT_DIR}/FULL_STACK_CAPABILITY_AUDIT.json"

cat > "${OUTPUT_DIR}/FULL_STACK_CAPABILITY_AUDIT.md" <<EOF
# YNX Full-Stack Capability Audit

- Generated: ${NOW_UTC}
- Snapshot source: \`output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.json\`
- Alignment source: \`output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json\`

## Runtime anchor

- chain_id: \`${rpc_chain_id}\`
- height: \`${rpc_height}\`
- indexer_ok: \`${indexer_ok}\`
- ai_ok: \`${ai_ok}\`
- web4_ok: \`${web4_ok}\`
- website_ai_http: \`${website_ai_http:-unavailable}\`
- alignment_status: \`${alignment_status}\`

## Capability matrix

| Surface | Current state | Boundary | Still needed |
|---|---|---|---|
| Chain / RPC | live public testnet | not mainnet-grade | validator redundancy, durability, audit |
| Web4 policy / session / agents | runnable local and live | protected writes only | more hardening, provider integrations |
| AI settlement / jobs / vaults | runnable local and live on public testnet | not production financial infra | persistence, telemetry, legal/audit maturity |
| AI agent spending | partly live through testnet rails | bounded only | provider spend rails, legal/compliance review |
| Trace / accountability / forensics | implemented with protected access | observation only, no seizure authority | more label providers, detectors, persistence |
| Public explorer trace preview | live redacted preview | no full public lineage | UX polish without losing redaction |
| Bridge routes | live public bridge with mixed maturity | ${bridge_full_loop_tested}/${bridge_routes} full-loop-tested only | Sepolia signer + BNB testnet lockbox/signer |
| YNX Card Mock | runnable mock logic, not issuer-backed | mock control plane only | issuer/processor integration, KYC/compliance/legal entity |
| Docs / grant / outreach | repo-ready materials and packs | not auto-submitted or auto-published | manual tailoring and approval |

## Security status

- Overall: \`guarded_testnet_scope\`
- Strengths:
  - policy-scoped writes
  - public-versus-protected trace boundary
  - bounded mock-card authorization model
  - explicit mock / testnet / provider-dependent separation
- Current gaps:
  - live AI health forensic counters still lag local code
  - bridge route completion remains uneven
  - real issuer/provider integrations are not present

## Funds-safety status

- Overall: \`safe_by_default_for_current_scope\`
- Guarantees now:
  - no live custody claim
  - no real card issuance in the current mock surface
  - no production issuer credentials required for current card demo
  - bridge blockers are explicit and configuration-scoped
- Not yet guaranteed:
  - mainnet real-value funds safety
  - provider-side settlement guarantees
  - institutional operational controls

## Compliance boundary

- Current position: \`non_custodial_public_testnet_infrastructure\`
- Do not imply:
  - finished legal sign-off
  - completed external audit coverage
  - licensed redemption or custody
  - issuer-backed production card launch

## Top current risks

1. Bridge route gap — still only \`${bridge_full_loop_tested}/${bridge_routes}\` full-loop-tested.
2. AI visibility gap — live health still does not expose local forensic workflow counters.
3. Provider dependency gap — YNX Card and programmable spend rails remain pre-provider and pre-legal-entity.

## Best companion artifacts

- \`docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md\`
- \`docs/zh/YNX_全栈真相矩阵_2026_06_27.md\`
- \`output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md\`
- \`output/full_stack_evidence_pack_latest/MANIFEST.md\`
- \`output/grant_visibility_pack_latest/MANIFEST.md\`
- \`output/executive_closeout_pack_latest/MANIFEST.md\`
EOF

rm -rf "${LATEST_DIR}"
mkdir -p "${LATEST_DIR}"
cp -R "${OUTPUT_DIR}/." "${LATEST_DIR}/"

echo "Full-stack capability audit ready:"
echo "- Folder: ${OUTPUT_DIR}"
echo "Stable latest capability audit:"
echo "- Folder: ${LATEST_DIR}"
