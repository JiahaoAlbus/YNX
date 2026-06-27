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
  scripts/verify_live_runtime_alignment.sh [--output-dir DIR]

Run a live runtime alignment audit against public YNX endpoints and report
where live deployment currently matches or lags current local/runtime
expectations.

This script reuses current_full_stack_status_snapshot.sh and produces:
  - LIVE_RUNTIME_ALIGNMENT.json
  - LIVE_RUNTIME_ALIGNMENT.md

Exit codes:
  0 => no FAIL-level findings (PASS or WARN overall)
  1 => one or more FAIL-level findings
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
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "$bin is required" >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"
OUTPUT_BASE_DIR="${REPO_ROOT}/output"
LATEST_DIR="${OUTPUT_BASE_DIR}/live_runtime_alignment_latest"

STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
SNAPSHOT_OUTPUT_DIR="${OUTPUT_BASE_DIR}/current_full_stack_status_${STAMP_LOCAL}"
if [[ -z "${OUTPUT_DIR:-}" ]]; then
  OUTPUT_DIR="${OUTPUT_BASE_DIR}/live_runtime_alignment_${STAMP_LOCAL}"
fi
mkdir -p "${OUTPUT_DIR}"

bash "${REPO_ROOT}/scripts/current_full_stack_status_snapshot.sh" --output-dir "${SNAPSHOT_OUTPUT_DIR}" >/dev/null

SNAPSHOT_JSON="${SNAPSHOT_OUTPUT_DIR}/CURRENT_FULL_STACK_STATUS.json"
ALIGNMENT_JSON="${OUTPUT_DIR}/LIVE_RUNTIME_ALIGNMENT.json"
ALIGNMENT_MD="${OUTPUT_DIR}/LIVE_RUNTIME_ALIGNMENT.md"

jq -n --slurpfile snapshot "${SNAPSHOT_JSON}" '
  def finding($id; $severity; $status; $summary; $detail):
    {
      id: $id,
      severity: $severity,
      status: $status,
      summary: $summary,
      detail: $detail
    };

  ($snapshot[0]) as $s
  | ($s.live.rpc.catching_up == false and (($s.live.rpc.chain_id // "") != "") and (($s.live.rpc.height // "") != "")) as $rpc_ok
  | ($s.live.indexer.ok == true) as $indexer_ok
  | ($s.live.ai.ok == true and $s.live.ai.policy_enforced == true and $s.live.ai.has_web4_authorizer == true) as $ai_ok
  | ($s.live.web4.ok == true and $s.live.web4.policy_enforcement == true and $s.live.web4.internal_authorizer == true) as $web4_ok
  | (($s.live.public_surfaces.explorer_http // "") | startswith("HTTP/")) as $explorer_up
  | (($s.live.public_surfaces.website_ai_http // "") | startswith("HTTP/")) as $website_up
  | (($s.live.bridge.summary.full_loop_tested // 0) >= 2) as $bridge_min_ok
  | (($s.alignment.ai_runtime_visibility.forensics_review_breakdown_exposed_live // false) == true) as $forensics_review_visible
  | (($s.alignment.ai_runtime_visibility.forensics_escalation_breakdown_exposed_live // false) == true) as $forensics_escalation_visible
  | [
      (if $rpc_ok then
        finding("rpc_live"; "info"; "PASS"; "RPC is live and not catching up"; ("chain_id=" + ($s.live.rpc.chain_id // "") + ", height=" + (($s.live.rpc.height // "") | tostring)))
      else
        finding("rpc_live"; "critical"; "FAIL"; "RPC is not in a healthy live state"; ("catching_up=" + (($s.live.rpc.catching_up // null) | tostring)))
      end),
      (if $indexer_ok then
        finding("indexer_live"; "info"; "PASS"; "Indexer health is ok"; ("last_indexed=" + (($s.live.indexer.last_indexed // "") | tostring)))
      else
        finding("indexer_live"; "critical"; "FAIL"; "Indexer health is not ok"; "Public indexer health endpoint did not return ok=true")
      end),
      (if $ai_ok then
        finding("ai_runtime"; "info"; "PASS"; "AI gateway is live, policy-enforced, and Web4-authorized"; ("llm=" + ($s.live.ai.llm_provider // "") + "/" + ($s.live.ai.llm_model // "")))
      else
        finding("ai_runtime"; "critical"; "FAIL"; "AI gateway runtime boundary is not fully healthy"; ("ok=" + (($s.live.ai.ok // null) | tostring) + ", policy_enforced=" + (($s.live.ai.policy_enforced // null) | tostring) + ", has_web4_authorizer=" + (($s.live.ai.has_web4_authorizer // null) | tostring)))
      end),
      (if $web4_ok then
        finding("web4_runtime"; "info"; "PASS"; "Web4 hub is live and enforcing policy/internal authorization"; "ok=true, policy_enforcement=true, internal_authorizer=true")
      else
        finding("web4_runtime"; "critical"; "FAIL"; "Web4 hub readiness boundary is not fully healthy"; ("ok=" + (($s.live.web4.ok // null) | tostring) + ", policy_enforcement=" + (($s.live.web4.policy_enforcement // null) | tostring) + ", internal_authorizer=" + (($s.live.web4.internal_authorizer // null) | tostring)))
      end),
      (if $explorer_up and $website_up then
        finding("public_surfaces"; "info"; "PASS"; "Explorer and website /ai are reachable"; (($s.live.public_surfaces.explorer_http // "") + " ; " + ($s.live.public_surfaces.website_ai_http // "")))
      else
        finding("public_surfaces"; "critical"; "FAIL"; "One or more public surfaces are not reachable"; ("explorer=" + ($s.live.public_surfaces.explorer_http // "missing") + ", website_ai=" + ($s.live.public_surfaces.website_ai_http // "missing")))
      end),
      (if $bridge_min_ok then
        finding("bridge_truth"; "warn"; "WARN"; "Bridge is live but not fully complete"; ("full_loop_tested=" + (($s.live.bridge.summary.full_loop_tested // 0) | tostring) + "/" + (($s.live.bridge.summary.routes // 0) | tostring) + ", automatic_loop_ready=" + (($s.live.bridge.summary.automatic_loop_ready // 0) | tostring)))
      else
        finding("bridge_truth"; "critical"; "FAIL"; "Bridge live truth is below the current minimum defended baseline"; ("full_loop_tested=" + (($s.live.bridge.summary.full_loop_tested // 0) | tostring) + "/" + (($s.live.bridge.summary.routes // 0) | tostring)))
      end),
      (if $forensics_review_visible and $forensics_escalation_visible then
        finding("ai_forensics_visibility"; "info"; "PASS"; "Live AI health exposes the newer forensic workflow breakdown"; "forensics review and escalation counters are both visible live")
      else
        finding("ai_forensics_visibility"; "warn"; "WARN"; "Live AI health still lags current local forensic workflow visibility"; ($s.alignment.ai_runtime_visibility.note // "live/local runtime visibility mismatch"))
      end)
    ] as $findings
  | {
      generated_at_utc: ($s.generated_at_utc // ""),
      snapshot_path: $s,
      overall_status:
        (if ($findings | any(.status == "FAIL")) then "FAIL"
         elif ($findings | any(.status == "WARN")) then "WARN"
         else "PASS"
         end),
      findings: $findings
    }
' > "${ALIGNMENT_JSON}"

overall_status="$(jq -r '.overall_status' "${ALIGNMENT_JSON}")"
pass_count="$(jq '[.findings[] | select(.status=="PASS")] | length' "${ALIGNMENT_JSON}")"
warn_count="$(jq '[.findings[] | select(.status=="WARN")] | length' "${ALIGNMENT_JSON}")"
fail_count="$(jq '[.findings[] | select(.status=="FAIL")] | length' "${ALIGNMENT_JSON}")"

{
  echo "# YNX Live Runtime Alignment Report"
  echo
  echo "- Generated: $(jq -r '.generated_at_utc' "${ALIGNMENT_JSON}")"
  echo "- Overall status: \`${overall_status}\`"
  echo "- PASS: \`${pass_count}\`"
  echo "- WARN: \`${warn_count}\`"
  echo "- FAIL: \`${fail_count}\`"
  echo
  echo "## Findings"
  echo
  jq -r '.findings[] | "- [`" + .status + "`] **" + .id + "** — " + .summary + "  \n  Detail: " + .detail' "${ALIGNMENT_JSON}"
  echo
  echo "## Supporting snapshot"
  echo
  echo "- [CURRENT_FULL_STACK_STATUS.md](/Users/huangjiahao/Desktop/YNX/output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md)"
  echo "- [CURRENT_FULL_STACK_STATUS.json](/Users/huangjiahao/Desktop/YNX/output/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.json)"
} > "${ALIGNMENT_MD}"

rm -rf "${LATEST_DIR}"
mkdir -p "${LATEST_DIR}"
cp -R "${OUTPUT_DIR}/." "${LATEST_DIR}/"

echo "Live runtime alignment report captured:"
echo "- ${ALIGNMENT_JSON}"
echo "- ${ALIGNMENT_MD}"
echo "Stable latest alignment report:"
echo "- ${LATEST_DIR}/LIVE_RUNTIME_ALIGNMENT.json"
echo "- ${LATEST_DIR}/LIVE_RUNTIME_ALIGNMENT.md"

if [[ "${overall_status}" == "FAIL" ]]; then
  exit 1
fi
