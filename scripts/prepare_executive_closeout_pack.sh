#!/usr/bin/env bash
set -euo pipefail

RUN_DOCS=1
REFRESH_DEPENDENCIES=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-docs)
      RUN_DOCS=0
      shift
      ;;
    --reuse-latest)
      REFRESH_DEPENDENCIES=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_executive_closeout_pack.sh [--skip-docs] [--reuse-latest]

Generate the highest-level YNX closeout pack that orchestrates:
  - latest live snapshot
  - latest runtime alignment audit
  - latest founder/operator evidence pack
  - latest grant/visibility pack

and wraps them in one stable executive handoff folder and archive.
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

if command -v shasum >/dev/null 2>&1; then
  HASH_CMD="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then
  HASH_CMD="sha256sum"
else
  echo "shasum or sha256sum is required" >&2
  exit 1
fi

STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
OUTPUT_BASE="${REPO_ROOT}/output"
OUT_DIR="${OUTPUT_BASE}/executive_closeout_pack_${STAMP_LOCAL}"
LATEST_DIR="${OUTPUT_BASE}/executive_closeout_pack_latest"

mkdir -p "${OUT_DIR}/reports" "${OUT_DIR}/docs/en" "${OUT_DIR}/docs/zh"

if [[ "${RUN_DOCS}" -eq 1 ]]; then
  bash ./scripts/verify_docs_readiness.sh
fi

if [[ "${REFRESH_DEPENDENCIES}" -eq 1 ]]; then
  bash ./scripts/current_full_stack_status_snapshot.sh >/dev/null
  bash ./scripts/verify_live_runtime_alignment.sh >/dev/null
  bash ./scripts/prepare_bridge_blocker_packet.sh >/dev/null
  bash ./scripts/prepare_live_alignment_rollout_packet.sh --reuse-latest >/dev/null
  bash ./scripts/prepare_card_provider_readiness_pack.sh >/dev/null
  bash ./scripts/prepare_builder_readiness_pack.sh >/dev/null
  bash ./scripts/prepare_external_launchpad_pack.sh >/dev/null
  bash ./scripts/prepare_current_state_board_pack.sh >/dev/null
  bash ./scripts/prepare_audience_map_pack.sh >/dev/null
  bash ./scripts/prepare_full_stack_evidence_pack.sh >/dev/null
  bash ./scripts/prepare_grant_visibility_pack.sh >/dev/null
fi

declare -a TOP_DOCS=(
  "README.md"
  "docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md"
  "docs/en/YNX_CURRENT_STATE_BOARD_2026_06_28.md"
  "docs/en/FINAL_FULL_STACK_HANDOFF_2026_06_27.md"
  "docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md"
  "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md"
  "docs/zh/当前全链状态与对齐快照_2026_06_27.md"
  "docs/zh/YNX_当前状态看板_2026_06_28.md"
  "docs/zh/最终全链交付总览_2026_06_27.md"
  "docs/zh/YNX_全栈真相矩阵_2026_06_27.md"
  "docs/zh/合规就绪包_2026_06_13.md"
)

for file in "${TOP_DOCS[@]}"; do
  mkdir -p "${OUT_DIR}/$(dirname "${file}")"
  cp "${file}" "${OUT_DIR}/${file}"
done

cp -R "${OUTPUT_BASE}/current_full_stack_status_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/live_runtime_alignment_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/bridge_blocker_packet_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/live_alignment_rollout_packet_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/full_stack_capability_audit_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/card_provider_readiness_pack_latest" "${OUT_DIR}/reports/" 2>/dev/null || true
cp -R "${OUTPUT_BASE}/builder_readiness_pack_latest" "${OUT_DIR}/reports/" 2>/dev/null || true
cp -R "${OUTPUT_BASE}/external_launchpad_pack_latest" "${OUT_DIR}/reports/" 2>/dev/null || true
cp -R "${OUTPUT_BASE}/audience_map_pack_latest" "${OUT_DIR}/reports/" 2>/dev/null || true
cp -R "${OUTPUT_BASE}/full_stack_evidence_pack_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/grant_visibility_pack_latest" "${OUT_DIR}/reports/"

LATEST_DOC_REPORT="$(ls -1t "${OUTPUT_BASE}"/docs_verification_report_*.md 2>/dev/null | head -n 1 || true)"
if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cp "${LATEST_DOC_REPORT}" "${OUT_DIR}/reports/"
fi

ALIGNMENT_STATUS="$(jq -r '.overall_status' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "UNKNOWN")"
BRIDGE_DETAIL="$(jq -r '.findings[] | select(.id=="bridge_truth") | .detail' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "")"
FORENSICS_DETAIL="$(jq -r '.findings[] | select(.id=="ai_forensics_visibility") | .detail' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "")"
CURRENT_SNAPSHOT_REL="reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md"
CURRENT_ALIGNMENT_REL="reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md"
FULL_STACK_PACK_REL="reports/full_stack_evidence_pack_latest/MANIFEST.md"
GRANT_PACK_REL="reports/grant_visibility_pack_latest/MANIFEST.md"

cat > "${OUT_DIR}/MANIFEST.md" <<EOF
# YNX Executive Closeout Pack

- Generated: ${NOW_UTC}
- Branch: $(git branch --show-current)
- Commit: $(git rev-parse HEAD)
- Commit short: $(git rev-parse --short HEAD)
- Runtime alignment status: ${ALIGNMENT_STATUS}

## Open these first

- [Closeout README](README.md)
- [Current full-stack snapshot](${CURRENT_SNAPSHOT_REL})
- [Truth matrix](docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md)
- [Live runtime alignment](${CURRENT_ALIGNMENT_REL})
- [Bridge blocker packet](reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md)
- [Live alignment rollout packet](reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md)
- [Capability audit](reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md)
- [External launchpad pack](reports/external_launchpad_pack_latest/MANIFEST.md)
- [Current state board](docs/en/YNX_CURRENT_STATE_BOARD_2026_06_28.md)
- [Builder readiness pack](reports/builder_readiness_pack_latest/MANIFEST.md)
- [Card provider readiness pack](reports/card_provider_readiness_pack_latest/MANIFEST.md)
- [Audience map pack](reports/audience_map_pack_latest/MANIFEST.md)
- [Founder/operator evidence pack](${FULL_STACK_PACK_REL})
- [Grant/visibility pack](${GRANT_PACK_REL})

## Current truth anchors

- Bridge: ${BRIDGE_DETAIL}
- AI/forensics visibility: ${FORENSICS_DETAIL}

## Included top-level docs

EOF

for file in "${TOP_DOCS[@]}"; do
  echo "- ${file}" >> "${OUT_DIR}/MANIFEST.md"
done

if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cat >> "${OUT_DIR}/MANIFEST.md" <<EOF

## Included docs verification

- [Docs verification report](reports/$(basename "${LATEST_DOC_REPORT}"))
EOF
fi

cat > "${OUT_DIR}/ARTIFACT_INDEX.json" <<EOF
{
  "generated_at_utc": "${NOW_UTC}",
  "branch": "$(git branch --show-current)",
  "commit": "$(git rev-parse HEAD)",
  "commit_short": "$(git rev-parse --short HEAD)",
  "runtime_alignment_status": "${ALIGNMENT_STATUS}",
  "truth": {
    "bridge": "${BRIDGE_DETAIL}",
    "ai_forensics_visibility": "${FORENSICS_DETAIL}"
  },
  "artifacts": {
    "executive_manifest": "MANIFEST.md",
    "executive_readme": "README.md",
    "executive_checklist": "EXECUTIVE_CHECKLIST.md",
    "current_full_stack_snapshot_md": "${CURRENT_SNAPSHOT_REL}",
    "truth_matrix_en": "docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md",
    "truth_matrix_zh": "docs/zh/YNX_全栈真相矩阵_2026_06_27.md",
    "runtime_alignment_md": "${CURRENT_ALIGNMENT_REL}",
    "bridge_blocker_packet_md": "reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md",
    "live_alignment_rollout_packet_md": "reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md",
    "capability_audit_md": "reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md",
    "external_launchpad_manifest": "reports/external_launchpad_pack_latest/MANIFEST.md",
    "current_state_board_en": "docs/en/YNX_CURRENT_STATE_BOARD_2026_06_28.md",
    "current_state_board_zh": "docs/zh/YNX_当前状态看板_2026_06_28.md",
    "builder_readiness_manifest": "reports/builder_readiness_pack_latest/MANIFEST.md",
    "card_provider_readiness_manifest": "reports/card_provider_readiness_pack_latest/MANIFEST.md",
    "audience_map_manifest": "reports/audience_map_pack_latest/MANIFEST.md",
    "full_stack_evidence_manifest": "${FULL_STACK_PACK_REL}",
    "grant_visibility_manifest": "${GRANT_PACK_REL}",
    "sha256sums": "SHA256SUMS.txt"
  }
}
EOF

cat > "${OUT_DIR}/README.md" <<'EOF'
# YNX Executive Closeout Pack

Recommended open order:

1. `MANIFEST.md`
2. `reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md`
3. `docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md`
4. `reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md`
5. `reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md`
6. `reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md`
7. `reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md`
8. `reports/external_launchpad_pack_latest/MANIFEST.md`
9. `docs/en/YNX_CURRENT_STATE_BOARD_2026_06_28.md`
10. `reports/builder_readiness_pack_latest/MANIFEST.md`
11. `reports/card_provider_readiness_pack_latest/MANIFEST.md`
12. `reports/audience_map_pack_latest/MANIFEST.md`
13. `reports/full_stack_evidence_pack_latest/MANIFEST.md`
14. `reports/grant_visibility_pack_latest/MANIFEST.md`
15. `ARTIFACT_INDEX.json`
16. `SHA256SUMS.txt`
EOF

cat > "${OUT_DIR}/EXECUTIVE_CHECKLIST.md" <<'EOF'
# Executive Checklist

- [ ] Review current full-stack snapshot
- [ ] Review runtime alignment WARN/FAIL items
- [ ] Review bridge blockers before claiming route readiness
- [ ] Review founder/operator evidence pack
- [ ] Review grant/visibility pack before outreach
- [ ] Keep all external wording inside current truthful public-testnet scope
EOF

(
  cd "${OUT_DIR}"
  find . -type f ! -name 'SHA256SUMS.txt' -print0 | sort -z | xargs -0 ${HASH_CMD} > SHA256SUMS.txt
)

rm -rf "${LATEST_DIR}"
mkdir -p "${LATEST_DIR}"
cp -R "${OUT_DIR}/." "${LATEST_DIR}/"

(
  cd "${OUTPUT_BASE}"
  tar -czf "executive_closeout_pack_${STAMP_LOCAL}.tar.gz" "executive_closeout_pack_${STAMP_LOCAL}"
)

echo "Executive closeout pack ready:"
echo "- Folder: ${OUT_DIR}"
echo "- Archive: ${OUTPUT_BASE}/executive_closeout_pack_${STAMP_LOCAL}.tar.gz"
echo "Stable latest executive closeout pack:"
echo "- Folder: ${LATEST_DIR}"
