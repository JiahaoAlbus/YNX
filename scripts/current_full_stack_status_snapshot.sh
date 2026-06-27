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
  scripts/current_full_stack_status_snapshot.sh [--output-dir DIR]

Generate a current YNX full-stack status snapshot from live public endpoints.

Environment:
  YNX_FETCH_TIMEOUT_SEC     default: 15
  YNX_RPC_STATUS_URL        default: https://rpc.ynxweb4.com/status
  YNX_INDEXER_HEALTH_URL    default: https://indexer.ynxweb4.com/health
  YNX_AI_HEALTH_URL         default: https://ai.ynxweb4.com/health
  YNX_WEB4_READY_URL        default: https://web4.ynxweb4.com/ready
  YNX_BRIDGE_HEALTH_URL     default: https://rpc.ynxweb4.com/bridge/health
  YNX_BRIDGE_ROUTES_URL     default: https://rpc.ynxweb4.com/bridge/route-readiness
  YNX_EXPLORER_URL          default: https://explorer.ynxweb4.com/
  YNX_WEBSITE_AI_URL        default: https://www.ynxweb4.com/ai
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
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
FETCH_TIMEOUT_SEC="${YNX_FETCH_TIMEOUT_SEC:-15}"

if [[ -z "${OUTPUT_DIR:-}" ]]; then
  OUTPUT_DIR="${REPO_ROOT}/output/current_full_stack_status_${STAMP_LOCAL}"
fi
mkdir -p "${OUTPUT_DIR}/responses"

RPC_STATUS_URL="${YNX_RPC_STATUS_URL:-https://rpc.ynxweb4.com/status}"
INDEXER_HEALTH_URL="${YNX_INDEXER_HEALTH_URL:-https://indexer.ynxweb4.com/health}"
AI_HEALTH_URL="${YNX_AI_HEALTH_URL:-https://ai.ynxweb4.com/health}"
WEB4_READY_URL="${YNX_WEB4_READY_URL:-https://web4.ynxweb4.com/ready}"
BRIDGE_HEALTH_URL="${YNX_BRIDGE_HEALTH_URL:-https://rpc.ynxweb4.com/bridge/health}"
BRIDGE_ROUTES_URL="${YNX_BRIDGE_ROUTES_URL:-https://rpc.ynxweb4.com/bridge/route-readiness}"
EXPLORER_URL="${YNX_EXPLORER_URL:-https://explorer.ynxweb4.com/}"
WEBSITE_AI_URL="${YNX_WEBSITE_AI_URL:-https://www.ynxweb4.com/ai}"

fetch_json() {
  local name="$1"
  local url="$2"
  if curl -fsS --max-time "${FETCH_TIMEOUT_SEC}" "${url}" > "${OUTPUT_DIR}/responses/${name}.json"; then
    return 0
  fi
  echo "{\"ok\":false,\"error\":\"fetch_failed\",\"url\":\"${url}\"}" > "${OUTPUT_DIR}/responses/${name}.json"
  return 1
}

fetch_headers() {
  local name="$1"
  local url="$2"
  if curl -I -sS --max-time "${FETCH_TIMEOUT_SEC}" "${url}" > "${OUTPUT_DIR}/responses/${name}.headers"; then
    return 0
  fi
  : > "${OUTPUT_DIR}/responses/${name}.headers"
  return 1
}

fetch_json rpc_status "${RPC_STATUS_URL}" || true
fetch_json indexer_health "${INDEXER_HEALTH_URL}" || true
fetch_json ai_health "${AI_HEALTH_URL}" || true
fetch_json web4_ready "${WEB4_READY_URL}" || true
fetch_json bridge_health "${BRIDGE_HEALTH_URL}" || true
fetch_json bridge_routes "${BRIDGE_ROUTES_URL}" || true
fetch_headers explorer "${EXPLORER_URL}" || true
fetch_headers website_ai "${WEBSITE_AI_URL}" || true

export SNAPSHOT_OUTPUT_DIR="${OUTPUT_DIR}"
export SNAPSHOT_NOW_UTC="${NOW_UTC}"
export SNAPSHOT_RPC_STATUS_URL="${RPC_STATUS_URL}"
export SNAPSHOT_INDEXER_HEALTH_URL="${INDEXER_HEALTH_URL}"
export SNAPSHOT_AI_HEALTH_URL="${AI_HEALTH_URL}"
export SNAPSHOT_WEB4_READY_URL="${WEB4_READY_URL}"
export SNAPSHOT_BRIDGE_HEALTH_URL="${BRIDGE_HEALTH_URL}"
export SNAPSHOT_BRIDGE_ROUTES_URL="${BRIDGE_ROUTES_URL}"
export SNAPSHOT_EXPLORER_URL="${EXPLORER_URL}"
export SNAPSHOT_WEBSITE_AI_URL="${WEBSITE_AI_URL}"

explorer_status="$(awk '/^HTTP\//{print; exit}' "${OUTPUT_DIR}/responses/explorer.headers" 2>/dev/null || true)"
website_ai_status="$(awk '/^HTTP\//{print; exit}' "${OUTPUT_DIR}/responses/website_ai.headers" 2>/dev/null || true)"
rpc_chain_id="$(jq -r '.result.node_info.network // ""' "${OUTPUT_DIR}/responses/rpc_status.json" 2>/dev/null || true)"
rpc_height="$(jq -r '.result.sync_info.latest_block_height // ""' "${OUTPUT_DIR}/responses/rpc_status.json" 2>/dev/null || true)"
rpc_catching_up="$(jq -r '(.result.sync_info.catching_up // false) | tostring' "${OUTPUT_DIR}/responses/rpc_status.json" 2>/dev/null || true)"
indexer_ok="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/indexer_health.json" 2>/dev/null || true)"
indexer_last_indexed="$(jq -r '.last_indexed // ""' "${OUTPUT_DIR}/responses/indexer_health.json" 2>/dev/null || true)"
indexer_latest_seen="$(jq -r '.latest_seen // ""' "${OUTPUT_DIR}/responses/indexer_health.json" 2>/dev/null || true)"
ai_ok="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/ai_health.json" 2>/dev/null || true)"
ai_policy_enforced="$(jq -r '.enforce_policy // false' "${OUTPUT_DIR}/responses/ai_health.json" 2>/dev/null || true)"
ai_llm_provider="$(jq -r '.intelligence.llm_provider // ""' "${OUTPUT_DIR}/responses/ai_health.json" 2>/dev/null || true)"
ai_llm_model="$(jq -r '.intelligence.model // ""' "${OUTPUT_DIR}/responses/ai_health.json" 2>/dev/null || true)"
ai_onchain_ready="$(jq -r '.onchain.ready // false' "${OUTPUT_DIR}/responses/ai_health.json" 2>/dev/null || true)"
web4_ok="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/web4_ready.json" 2>/dev/null || true)"
web4_policy_enforcement="$(jq -r '.checks.policy_enforcement // false' "${OUTPUT_DIR}/responses/web4_ready.json" 2>/dev/null || true)"
web4_internal_authorizer="$(jq -r '.checks.internal_authorizer // false' "${OUTPUT_DIR}/responses/web4_ready.json" 2>/dev/null || true)"
bridge_ok="$(jq -r '.ok // false' "${OUTPUT_DIR}/responses/bridge_health.json" 2>/dev/null || true)"

jq -n \
  --arg generated_at_utc "${NOW_UTC}" \
  --arg rpc_url "${RPC_STATUS_URL}" \
  --arg rpc_chain_id "${rpc_chain_id}" \
  --arg rpc_height "${rpc_height}" \
  --argjson rpc_catching_up "$(jq '.result.sync_info.catching_up // false' "${OUTPUT_DIR}/responses/rpc_status.json" 2>/dev/null || echo false)" \
  --arg indexer_url "${INDEXER_HEALTH_URL}" \
  --argjson indexer_ok "${indexer_ok}" \
  --arg indexer_last_indexed "${indexer_last_indexed}" \
  --arg indexer_latest_seen "${indexer_latest_seen}" \
  --arg ai_url "${AI_HEALTH_URL}" \
  --argjson ai_ok "${ai_ok}" \
  --argjson ai_policy_enforced "${ai_policy_enforced}" \
  --arg ai_llm_provider "${ai_llm_provider}" \
  --arg ai_llm_model "${ai_llm_model}" \
  --argjson ai_onchain_ready "${ai_onchain_ready}" \
  --arg web4_url "${WEB4_READY_URL}" \
  --argjson web4_ok "${web4_ok}" \
  --argjson web4_policy_enforcement "${web4_policy_enforcement}" \
  --argjson web4_internal_authorizer "${web4_internal_authorizer}" \
  --arg bridge_health_url "${BRIDGE_HEALTH_URL}" \
  --arg bridge_routes_url "${BRIDGE_ROUTES_URL}" \
  --argjson bridge_ok "${bridge_ok}" \
  --arg explorer_url "${EXPLORER_URL}" \
  --arg explorer_http "${explorer_status}" \
  --arg website_ai_url "${WEBSITE_AI_URL}" \
  --arg website_ai_http "${website_ai_status}" \
  --slurpfile ai_health_raw "${OUTPUT_DIR}/responses/ai_health.json" \
  --slurpfile bridge_routes_raw "${OUTPUT_DIR}/responses/bridge_routes.json" \
  '{
    generated_at_utc: $generated_at_utc,
    live: {
      rpc: {
        url: $rpc_url,
        chain_id: $rpc_chain_id,
        height: $rpc_height,
        catching_up: $rpc_catching_up
      },
      indexer: {
        url: $indexer_url,
        ok: $indexer_ok,
        last_indexed: $indexer_last_indexed,
        latest_seen: $indexer_latest_seen
      },
      ai: {
        url: $ai_url,
        ok: $ai_ok,
        policy_enforced: $ai_policy_enforced,
        llm_provider: $ai_llm_provider,
        llm_model: $ai_llm_model,
        onchain_ready: $ai_onchain_ready,
        stats: ($ai_health_raw[0].stats // {})
      },
      web4: {
        url: $web4_url,
        ok: $web4_ok,
        policy_enforcement: $web4_policy_enforcement,
        internal_authorizer: $web4_internal_authorizer
      },
      bridge: {
        health_url: $bridge_health_url,
        routes_url: $bridge_routes_url,
        ok: $bridge_ok,
        summary: ($bridge_routes_raw[0].summary // {}),
        priority_actions: ($bridge_routes_raw[0].actions // []),
        routes: (($bridge_routes_raw[0].items // []) | map({
          routeId,
          phase,
          automatic_loop_ready,
          blockers,
          required_configuration,
          recommended_action
        }))
      },
      public_surfaces: {
        explorer_url: $explorer_url,
        explorer_http: $explorer_http,
        website_ai_url: $website_ai_url,
        website_ai_http: $website_ai_http
      }
    },
    doc_entrypoints: {
      en_current_status: "docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md",
      zh_current_status: "docs/zh/当前全链状态与对齐快照_2026_06_27.md",
      en_compliance: "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md",
      zh_compliance: "docs/zh/合规就绪包_2026_06_13.md",
      en_readiness_gates: "docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md",
      zh_readiness_gates: "docs/zh/主网与行业级上线门禁.md"
    }
  }' > "${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json"

route_lines="$(jq -r '(.live.bridge.routes // []) | if length == 0 then "- none" else .[] | "- `\(.routeId)` — phase `\(.phase)`; blockers: \((.blockers // []) | if length == 0 then "none" else join(", ") end)" end' "${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json")"
bridge_actions_md="$(jq -r '
  (.live.bridge.priority_actions // []) as $actions
  | if ($actions | length) > 0 then
      $actions[] | "- \(.recommended_action // "no action")"
    else
      (.live.bridge.routes // [])
      | map(select((.blockers // []) | length > 0))
      | if length == 0 then
          "- none"
        else
          .[] | "- \(.routeId): \((.required_configuration // []) | if length == 0 then "manual blocker review" else join(", ") end)"
        end
    end
' "${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json")"
routes_total="$(jq -r '.live.bridge.summary.routes // ""' "${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json")"
full_loop_tested="$(jq -r '.live.bridge.summary.full_loop_tested // ""' "${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json")"
deposit_tested="$(jq -r '.live.bridge.summary.deposit_tested // ""' "${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json")"
automatic_loop_ready="$(jq -r '.live.bridge.summary.automatic_loop_ready // ""' "${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json")"
mapped_route_only="$(jq -r '.live.bridge.summary.mapped_route_only // ""' "${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json")"

cat > "${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.md" <<EOF
# YNX Current Full-Stack Status Snapshot

- Generated: ${NOW_UTC}
- Output directory: \`${OUTPUT_DIR}\`

## Live snapshot

- RPC: \`${rpc_chain_id}\` @ height \`${rpc_height}\`; catching_up=\`${rpc_catching_up}\`
- Indexer: ok=\`${indexer_ok}\`; last_indexed=\`${indexer_last_indexed}\`; latest_seen=\`${indexer_latest_seen}\`
- AI Gateway: ok=\`${ai_ok}\`; policy_enforced=\`${ai_policy_enforced}\`; llm=\`${ai_llm_provider}\` / \`${ai_llm_model}\`; onchain_ready=\`${ai_onchain_ready}\`
- Web4 Hub: ok=\`${web4_ok}\`; policy_enforcement=\`${web4_policy_enforcement}\`; internal_authorizer=\`${web4_internal_authorizer}\`
- Explorer: \`${explorer_status:-unavailable}\`
- Website /ai: \`${website_ai_status:-unavailable}\`

## Bridge summary

- routes: \`${routes_total}\`
- full_loop_tested: \`${full_loop_tested}\`
- deposit_tested: \`${deposit_tested}\`
- automatic_loop_ready: \`${automatic_loop_ready}\`
- mapped_route_only: \`${mapped_route_only}\`

## Route breakdown

${route_lines}

## Priority actions

${bridge_actions_md}

## Canonical docs

- \`docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md\`
- \`docs/zh/当前全链状态与对齐快照_2026_06_27.md\`
- \`docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md\`
- \`docs/zh/合规就绪包_2026_06_13.md\`
EOF

echo "Current full-stack status snapshot captured:"
echo "- ${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json"
echo "- ${OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.md"
