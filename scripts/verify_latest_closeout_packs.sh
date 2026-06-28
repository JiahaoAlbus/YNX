#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

if command -v shasum >/dev/null 2>&1; then
  HASH_CHECK_CMD="shasum -a 256 -c"
elif command -v sha256sum >/dev/null 2>&1; then
  HASH_CHECK_CMD="sha256sum -c"
else
  echo "shasum or sha256sum is required" >&2
  exit 1
fi

PACKS=(
  "output/builder_readiness_pack_latest"
  "output/audience_map_pack_latest"
  "output/full_stack_evidence_pack_latest"
  "output/grant_visibility_pack_latest"
  "output/executive_closeout_pack_latest"
)

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

need_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing file: $path"
}

need_dir() {
  local path="$1"
  [[ -d "$path" ]] || fail "missing directory: $path"
}

for pack in "${PACKS[@]}"; do
  need_dir "$pack"
  need_file "$pack/MANIFEST.md"
  need_file "$pack/README.md"
  need_file "$pack/SHA256SUMS.txt"
  (
    cd "$pack"
    ${HASH_CHECK_CMD} SHA256SUMS.txt >/dev/null
  ) || fail "hash verification failed for $pack"
done

need_file "output/executive_closeout_pack_latest/ARTIFACT_INDEX.json"
need_file "output/executive_closeout_pack_latest/EXECUTIVE_CHECKLIST.md"
need_file "output/full_stack_evidence_pack_latest/HANDOFF_CHECKLIST.md"
need_file "output/grant_visibility_pack_latest/OUTREACH_CHECKLIST.md"
need_file "output/full_stack_evidence_pack_latest/reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md"
need_file "output/full_stack_evidence_pack_latest/reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md"
need_file "output/full_stack_evidence_pack_latest/reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md"
need_file "output/full_stack_evidence_pack_latest/reports/builder_readiness_pack_latest/MANIFEST.md"
need_file "output/full_stack_evidence_pack_latest/reports/card_provider_readiness_pack_latest/MANIFEST.md"
need_file "output/full_stack_evidence_pack_latest/reports/audience_map_pack_latest/MANIFEST.md"
need_file "output/grant_visibility_pack_latest/reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md"
need_file "output/grant_visibility_pack_latest/reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md"
need_file "output/grant_visibility_pack_latest/reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md"
need_file "output/executive_closeout_pack_latest/reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md"
need_file "output/executive_closeout_pack_latest/reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md"
need_file "output/executive_closeout_pack_latest/reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md"
need_file "output/executive_closeout_pack_latest/reports/builder_readiness_pack_latest/MANIFEST.md"
need_file "output/executive_closeout_pack_latest/reports/card_provider_readiness_pack_latest/MANIFEST.md"
need_file "output/executive_closeout_pack_latest/reports/audience_map_pack_latest/MANIFEST.md"
need_file "output/full_stack_evidence_pack_latest/docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md"
need_file "output/full_stack_evidence_pack_latest/docs/zh/YNX_全栈真相矩阵_2026_06_27.md"
need_file "output/grant_visibility_pack_latest/docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md"
need_file "output/grant_visibility_pack_latest/docs/zh/YNX_全栈真相矩阵_2026_06_27.md"
need_file "output/executive_closeout_pack_latest/docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md"
need_file "output/executive_closeout_pack_latest/docs/zh/YNX_全栈真相矩阵_2026_06_27.md"

while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  need_file "output/executive_closeout_pack_latest/$rel"
done < <(
  jq -r '.artifacts | to_entries[] | .value' output/executive_closeout_pack_latest/ARTIFACT_INDEX.json
)

grep -q 'reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md' \
  output/full_stack_evidence_pack_latest/MANIFEST.md \
  || fail "full-stack evidence pack manifest missing snapshot link"

grep -q 'reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md' \
  output/grant_visibility_pack_latest/MANIFEST.md \
  || fail "grant visibility pack manifest missing alignment link"

grep -q 'docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md' \
  output/full_stack_evidence_pack_latest/MANIFEST.md \
  || fail "full-stack evidence pack manifest missing truth matrix link"

grep -q 'docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md' \
  output/grant_visibility_pack_latest/MANIFEST.md \
  || fail "grant visibility pack manifest missing truth matrix link"

grep -q 'reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md' \
  output/full_stack_evidence_pack_latest/MANIFEST.md \
  || fail "full-stack evidence pack manifest missing capability audit link"

grep -q 'reports/builder_readiness_pack_latest/MANIFEST.md' \
  output/full_stack_evidence_pack_latest/MANIFEST.md \
  || fail "full-stack evidence pack manifest missing builder readiness link"

grep -q 'reports/card_provider_readiness_pack_latest/MANIFEST.md' \
  output/full_stack_evidence_pack_latest/MANIFEST.md \
  || fail "full-stack evidence pack manifest missing card provider readiness link"

grep -q 'reports/audience_map_pack_latest/MANIFEST.md' \
  output/full_stack_evidence_pack_latest/MANIFEST.md \
  || fail "full-stack evidence pack manifest missing audience map link"

grep -q 'reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md' \
  output/grant_visibility_pack_latest/MANIFEST.md \
  || fail "grant visibility pack manifest missing capability audit link"

grep -q 'reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md' \
  output/full_stack_evidence_pack_latest/MANIFEST.md \
  || fail "full-stack evidence pack manifest missing rollout packet link"

grep -q 'reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md' \
  output/executive_closeout_pack_latest/MANIFEST.md \
  || fail "executive closeout pack manifest missing bridge blocker packet link"

grep -q 'docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md' \
  output/executive_closeout_pack_latest/MANIFEST.md \
  || fail "executive closeout pack manifest missing truth matrix link"

grep -q 'reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md' \
  output/executive_closeout_pack_latest/MANIFEST.md \
  || fail "executive closeout pack manifest missing capability audit link"

grep -q 'reports/builder_readiness_pack_latest/MANIFEST.md' \
  output/executive_closeout_pack_latest/MANIFEST.md \
  || fail "executive closeout pack manifest missing builder readiness link"

grep -q 'reports/card_provider_readiness_pack_latest/MANIFEST.md' \
  output/executive_closeout_pack_latest/MANIFEST.md \
  || fail "executive closeout pack manifest missing card provider readiness link"

grep -q 'reports/audience_map_pack_latest/MANIFEST.md' \
  output/executive_closeout_pack_latest/MANIFEST.md \
  || fail "executive closeout pack manifest missing audience map link"

grep -q 'reports/builder_readiness_pack_latest/MANIFEST.md' \
  output/audience_map_pack_latest/MANIFEST.md \
  || fail "audience map pack manifest missing builder readiness link"

echo "PASS: latest closeout packs are present, hashed, and internally linked."
