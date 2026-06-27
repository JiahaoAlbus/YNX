#!/usr/bin/env bash
set -euo pipefail

REFRESH_DEPENDENCIES=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reuse-latest)
      REFRESH_DEPENDENCIES=0
      shift
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_live_alignment_rollout_packet.sh [--reuse-latest] [--output-dir DIR]

Generate a focused operator rollout packet for the remaining live-versus-local
alignment gaps and bridge blockers.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

for bin in bash jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "$bin is required" >&2; exit 1; }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
OUTPUT_BASE="${REPO_ROOT}/output"
LATEST_DIR="${OUTPUT_BASE}/live_alignment_rollout_packet_latest"
if [[ -z "${OUTPUT_DIR:-}" ]]; then
  OUTPUT_DIR="${OUTPUT_BASE}/live_alignment_rollout_packet_${STAMP_LOCAL}"
fi
mkdir -p "${OUTPUT_DIR}"

if [[ "${REFRESH_DEPENDENCIES}" -eq 1 ]]; then
  "${REPO_ROOT}/scripts/current_full_stack_status_snapshot.sh" >/dev/null
  "${REPO_ROOT}/scripts/verify_live_runtime_alignment.sh" >/dev/null
  "${REPO_ROOT}/scripts/prepare_bridge_blocker_packet.sh" >/dev/null
fi

SNAPSHOT_JSON="${OUTPUT_BASE}/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.json"
ALIGNMENT_JSON="${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json"
BRIDGE_PACKET_JSON="${OUTPUT_BASE}/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.json"
OUT_JSON="${OUTPUT_DIR}/LIVE_ALIGNMENT_ROLLOUT_PACKET.json"
OUT_MD="${OUTPUT_DIR}/LIVE_ALIGNMENT_ROLLOUT_PACKET.md"

jq -n \
  --arg generated_at_utc "${NOW_UTC}" \
  --arg snapshot_rel "output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.json" \
  --arg alignment_rel "output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" \
  --arg bridge_packet_rel "output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.json" \
  --slurpfile snapshot "${SNAPSHOT_JSON}" \
  --slurpfile alignment "${ALIGNMENT_JSON}" \
  --slurpfile bridge "${BRIDGE_PACKET_JSON}" '
  ($snapshot[0]) as $s
  | ($alignment[0]) as $a
  | ($bridge[0]) as $b
  | ($a.findings // []) as $findings
  | ($findings | map(select(.status == "WARN" or .status == "FAIL"))) as $open_findings
  | {
      generated_at_utc: $generated_at_utc,
      current_truth: {
        bridge: ($b.summary // {}),
        ai_runtime_visibility: ($s.alignment.ai_runtime_visibility // {})
      },
      open_findings: $open_findings,
      rollout_sequence: [
        {
          step: 1,
          id: "ai_forensics_visibility_alignment",
          summary: "Roll live AI gateway so /health and /ready expose forensic review and escalation breakdown counters plus persistence metadata.",
          why_now: "This is the cleanest remaining live/local observability gap and is directly verifiable from public health surfaces.",
          success_criteria: [
            "GET https://ai.ynxweb4.com/health returns stats.forensic_cases_by_review_status",
            "GET https://ai.ynxweb4.com/health returns stats.forensic_cases_by_escalation_status",
            "GET https://ai.ynxweb4.com/health returns persistence.last_persist_at"
          ],
          verification_commands: [
            "curl -sS https://ai.ynxweb4.com/health | jq \".stats.forensic_cases_by_review_status\"",
            "curl -sS https://ai.ynxweb4.com/health | jq \".stats.forensic_cases_by_escalation_status\"",
            "curl -sS https://ai.ynxweb4.com/health | jq \".persistence.last_persist_at\""
          ],
          source_refs: [
            "infra/ai-gateway/server.js",
            "docs/en/YNX_v2_AI_SETTLEMENT_API.md",
            "output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md"
          ]
        },
        {
          step: 2,
          id: "sepolia_bridge_signer_alignment",
          summary: "Load the correct source lockbox owner signer into BRIDGE_SOURCE_EVM_PRIVATE_KEY for the two Sepolia routes.",
          why_now: "These routes are already deposit-tested and are the shortest path from 2/5 to 4/5 automatic-loop-ready.",
          success_criteria: [
            "eth-sepolia-eth no longer reports release_pending_signer",
            "eth-sepolia-usdc no longer reports release_pending_signer",
            "route-readiness automatic_loop_ready increases"
          ],
          verification_commands: [
            "curl -sS https://rpc.ynxweb4.com/bridge/route-readiness | jq \".items[] | select(.routeId==\\\"eth-sepolia-eth\\\" or .routeId==\\\"eth-sepolia-usdc\\\") | {routeId, blockers, automatic_loop_ready}\""
          ],
          source_refs: [
            "scripts/restore_sepolia_auto_release.sh",
            "output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md"
          ]
        },
        {
          step: 3,
          id: "bsc_lockbox_completion",
          summary: "Deploy and configure the BSC testnet source lockbox, set lockboxAddress, and then load BRIDGE_SOURCE_EVM_PRIVATE_KEY.",
          why_now: "This is the remaining route preventing the bridge from moving beyond mapped_route_only on all five routes.",
          success_criteria: [
            "bnb-testnet-bnb no longer reports source_lockbox_unconfigured",
            "bnb-testnet-bnb no longer remains mapped_route_only",
            "route-readiness deposit_tested or higher is visible for bnb-testnet-bnb"
          ],
          verification_commands: [
            "curl -sS https://rpc.ynxweb4.com/bridge/route-readiness | jq \".items[] | select(.routeId==\\\"bnb-testnet-bnb\\\") | {routeId, phase, blockers, automatic_loop_ready}\""
          ],
          source_refs: [
            "output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md"
          ]
        }
      ],
      artifact_refs: {
        snapshot_json: $snapshot_rel,
        alignment_json: $alignment_rel,
        bridge_packet_json: $bridge_packet_rel
      }
    }' > "${OUT_JSON}"

open_findings_md="$(jq -r '
  .open_findings
  | if length == 0 then
      "- none"
    else
      .[]
      | "- `\(.status)` **\(.id)** — \(.summary)\n  - detail: \(.detail)"
    end
' "${OUT_JSON}")"

rollout_md="$(jq -r '
  .rollout_sequence[]
  | "### Step \(.step) — \(.id)\n\n"
    + "- Summary: \(.summary)\n"
    + "- Why now: \(.why_now)\n"
    + "- Success criteria:\n"
    + ((.success_criteria // []) | map("  - " + .) | join("\n")) + "\n"
    + "- Verification commands:\n"
    + ((.verification_commands // []) | map("  - `" + . + "`") | join("\n")) + "\n"
    + "- Source refs:\n"
    + ((.source_refs // []) | map("  - `" + . + "`") | join("\n")) + "\n"
' "${OUT_JSON}")"

bridge_summary_routes="$(jq -r '.current_truth.bridge.routes // 0' "${OUT_JSON}")"
bridge_summary_full_loop="$(jq -r '.current_truth.bridge.full_loop_tested // 0' "${OUT_JSON}")"
bridge_summary_deposit="$(jq -r '.current_truth.bridge.deposit_tested // 0' "${OUT_JSON}")"
bridge_summary_auto="$(jq -r '.current_truth.bridge.automatic_loop_ready // 0' "${OUT_JSON}")"
ai_review_visible="$(jq -r '.current_truth.ai_runtime_visibility.forensics_review_breakdown_exposed_live // false' "${OUT_JSON}")"
ai_escalation_visible="$(jq -r '.current_truth.ai_runtime_visibility.forensics_escalation_breakdown_exposed_live // false' "${OUT_JSON}")"
ai_visibility_note="$(jq -r '.current_truth.ai_runtime_visibility.note // ""' "${OUT_JSON}")"

{
  printf '# YNX Live Alignment Rollout Packet\n\n'
  printf -- '- Generated: %s\n' "${NOW_UTC}"
  printf -- '- Snapshot source: [CURRENT_FULL_STACK_STATUS.json](/Users/huangjiahao/Desktop/YNX/output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.json)\n'
  printf -- '- Alignment source: [LIVE_RUNTIME_ALIGNMENT.json](/Users/huangjiahao/Desktop/YNX/output/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json)\n'
  printf -- '- Bridge packet source: [BRIDGE_BLOCKER_PACKET.json](/Users/huangjiahao/Desktop/YNX/output/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.json)\n\n'
  printf '## Current truth anchors\n\n'
  printf -- '- Bridge routes: `%s`\n' "${bridge_summary_routes}"
  printf -- '- Bridge full_loop_tested: `%s`\n' "${bridge_summary_full_loop}"
  printf -- '- Bridge deposit_tested: `%s`\n' "${bridge_summary_deposit}"
  printf -- '- Bridge automatic_loop_ready: `%s`\n' "${bridge_summary_auto}"
  printf -- '- Live AI health exposes forensic review breakdown: `%s`\n' "${ai_review_visible}"
  printf -- '- Live AI health exposes forensic escalation breakdown: `%s`\n' "${ai_escalation_visible}"
  printf -- '- Current AI visibility note: %s\n\n' "${ai_visibility_note}"
  printf '## Remaining open findings\n\n%s\n\n' "${open_findings_md}"
  printf '## Recommended rollout order\n\n%s\n' "${rollout_md}"
} > "${OUT_MD}"

rm -rf "${LATEST_DIR}"
mkdir -p "${LATEST_DIR}"
cp -R "${OUTPUT_DIR}/." "${LATEST_DIR}/"

echo "Live alignment rollout packet ready:"
echo "- ${OUT_JSON}"
echo "- ${OUT_MD}"
echo "Stable latest live alignment rollout packet:"
echo "- ${LATEST_DIR}/LIVE_ALIGNMENT_ROLLOUT_PACKET.json"
echo "- ${LATEST_DIR}/LIVE_ALIGNMENT_ROLLOUT_PACKET.md"
