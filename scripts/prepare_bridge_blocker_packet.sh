#!/usr/bin/env bash
set -euo pipefail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_bridge_blocker_packet.sh [--output-dir DIR]

Fetch current public bridge route-readiness and generate a focused remediation
packet for the current live blockers.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

for bin in curl jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "$bin is required" >&2; exit 1; }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
OUTPUT_BASE="${REPO_ROOT}/output"
LATEST_DIR="${OUTPUT_BASE}/bridge_blocker_packet_latest"
if [[ -z "${OUTPUT_DIR:-}" ]]; then
  OUTPUT_DIR="${OUTPUT_BASE}/bridge_blocker_packet_${STAMP_LOCAL}"
fi
mkdir -p "${OUTPUT_DIR}/responses"

BRIDGE_ROUTES_URL="${YNX_BRIDGE_ROUTES_URL:-https://rpc.ynxweb4.com/bridge/route-readiness}"

curl -fsS "${BRIDGE_ROUTES_URL}" > "${OUTPUT_DIR}/responses/bridge_route_readiness.json"

jq -n \
  --arg generated_at_utc "${NOW_UTC}" \
  --arg bridge_routes_url "${BRIDGE_ROUTES_URL}" \
  --slurpfile raw "${OUTPUT_DIR}/responses/bridge_route_readiness.json" '
  ($raw[0]) as $r
  | {
      generated_at_utc: $generated_at_utc,
      bridge_routes_url: $bridge_routes_url,
      summary: ($r.summary // {}),
      blockers: (($r.items // [])
        | map(select((.blockers // []) | length > 0))
        | map({
            routeId,
            phase,
            blocker_class,
            blockers,
            required_configuration,
            recommended_action,
            signer_diagnostics,
            evidence: {
              deposit_watcher_status: .evidence.deposit_watcher_status,
              release_adapter_status: .evidence.release_adapter_status,
              minted_deposits: .evidence.minted_deposits,
              released_withdrawals: .evidence.released_withdrawals
            }
          })),
      remediation_assets: {
        sepolia_restore_script: "scripts/restore_sepolia_auto_release.sh",
        current_status_doc_en: "docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md",
        current_status_doc_zh: "docs/zh/当前全链状态与对齐快照_2026_06_27.md",
        final_handoff_en: "docs/en/FINAL_FULL_STACK_HANDOFF_2026_06_27.md",
        final_handoff_zh: "docs/zh/最终全链交付总览_2026_06_27.md"
      }
    }' > "${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.json"

routes_md="$(jq -r '
  .blockers
  | if length == 0 then
      "- none"
    else
      .[]
      | "- `\(.routeId)` — phase `\(.phase)`; blocker_class `\(.blocker_class // "unknown")`; blockers: \((.blockers // []) | join(", "))"
    end
' "${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.json")"

actions_md="$(jq -r '
  .blockers
  | if length == 0 then
      "- none"
    else
      .[]
      | "- `\(.routeId)`: \(.recommended_action // "manual blocker review")"
    end
' "${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.json")"

summary_routes="$(jq -r '.summary.routes // 0' "${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.json")"
summary_full_loop="$(jq -r '.summary.full_loop_tested // 0' "${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.json")"
summary_deposit="$(jq -r '.summary.deposit_tested // 0' "${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.json")"
summary_auto="$(jq -r '.summary.automatic_loop_ready // 0' "${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.json")"

{
  printf '# YNX Bridge Blocker Packet\n\n'
  printf -- '- Generated: %s\n' "${NOW_UTC}"
  printf -- '- Source: `%s`\n\n' "${BRIDGE_ROUTES_URL}"
  printf '## Current truth\n\n'
  printf -- '- routes: `%s`\n' "${summary_routes}"
  printf -- '- full_loop_tested: `%s`\n' "${summary_full_loop}"
  printf -- '- deposit_tested: `%s`\n' "${summary_deposit}"
  printf -- '- automatic_loop_ready: `%s`\n\n' "${summary_auto}"
  printf '## Current live blockers\n\n%s\n\n' "${routes_md}"
  printf '## Current remediation actions\n\n%s\n\n' "${actions_md}"
  printf '## Existing remediation assets\n\n'
  printf -- '- [restore_sepolia_auto_release.sh](/Users/huangjiahao/Desktop/YNX/scripts/restore_sepolia_auto_release.sh)\n'
  printf -- '- [CURRENT_FULL_STACK_STATUS_2026_06_27.md](/Users/huangjiahao/Desktop/YNX/docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md)\n'
  printf -- '- [当前全链状态与对齐快照_2026_06_27.md](/Users/huangjiahao/Desktop/YNX/docs/zh/当前全链状态与对齐快照_2026_06_27.md)\n'
  printf -- '- [FINAL_FULL_STACK_HANDOFF_2026_06_27.md](/Users/huangjiahao/Desktop/YNX/docs/en/FINAL_FULL_STACK_HANDOFF_2026_06_27.md)\n'
  printf -- '- [最终全链交付总览_2026_06_27.md](/Users/huangjiahao/Desktop/YNX/docs/zh/最终全链交付总览_2026_06_27.md)\n\n'
  printf '## Safety notes\n\n'
  printf -- '- Do not claim `5/5 full_loop_tested` until live route-readiness changes.\n'
  printf -- '- Sepolia blockers are signer/config blockers, not proof that the route mapping is fake.\n'
  printf -- '- BSC blocker is still a deployment/configuration gap, not just a wording gap.\n'
} > "${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.md"

rm -rf "${LATEST_DIR}"
mkdir -p "${LATEST_DIR}"
cp -R "${OUTPUT_DIR}/." "${LATEST_DIR}/"

echo "Bridge blocker packet ready:"
echo "- ${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.json"
echo "- ${OUTPUT_DIR}/BRIDGE_BLOCKER_PACKET.md"
echo "Stable latest bridge blocker packet:"
echo "- ${LATEST_DIR}/BRIDGE_BLOCKER_PACKET.json"
echo "- ${LATEST_DIR}/BRIDGE_BLOCKER_PACKET.md"
