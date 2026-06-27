#!/usr/bin/env bash
set -euo pipefail

RUN_DOCS=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-docs)
      RUN_DOCS=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_executive_closeout_pack.sh [--skip-docs]

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

STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
OUTPUT_BASE="${REPO_ROOT}/output"
OUT_DIR="${OUTPUT_BASE}/executive_closeout_pack_${STAMP_LOCAL}"
LATEST_DIR="${OUTPUT_BASE}/executive_closeout_pack_latest"

mkdir -p "${OUT_DIR}/reports" "${OUT_DIR}/docs/en" "${OUT_DIR}/docs/zh"

if [[ "${RUN_DOCS}" -eq 1 ]]; then
  ./scripts/verify_docs_readiness.sh
fi

./scripts/current_full_stack_status_snapshot.sh >/dev/null
./scripts/verify_live_runtime_alignment.sh >/dev/null
./scripts/prepare_full_stack_evidence_pack.sh >/dev/null
./scripts/prepare_grant_visibility_pack.sh >/dev/null

declare -a TOP_DOCS=(
  "README.md"
  "docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md"
  "docs/en/FINAL_FULL_STACK_HANDOFF_2026_06_27.md"
  "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md"
  "docs/zh/当前全链状态与对齐快照_2026_06_27.md"
  "docs/zh/最终全链交付总览_2026_06_27.md"
  "docs/zh/合规就绪包_2026_06_13.md"
)

for file in "${TOP_DOCS[@]}"; do
  mkdir -p "${OUT_DIR}/$(dirname "${file}")"
  cp "${file}" "${OUT_DIR}/${file}"
done

cp -R "${OUTPUT_BASE}/current_full_stack_status_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/live_runtime_alignment_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/full_stack_evidence_pack_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/grant_visibility_pack_latest" "${OUT_DIR}/reports/"

LATEST_DOC_REPORT="$(ls -1t "${OUTPUT_BASE}"/docs_verification_report_*.md 2>/dev/null | head -n 1 || true)"
if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cp "${LATEST_DOC_REPORT}" "${OUT_DIR}/reports/"
fi

ALIGNMENT_STATUS="$(jq -r '.overall_status' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "UNKNOWN")"
BRIDGE_DETAIL="$(jq -r '.findings[] | select(.id=="bridge_truth") | .detail' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "")"
FORENSICS_DETAIL="$(jq -r '.findings[] | select(.id=="ai_forensics_visibility") | .detail' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "")"

cat > "${OUT_DIR}/MANIFEST.md" <<EOF
# YNX Executive Closeout Pack

- Generated: ${NOW_UTC}
- Branch: $(git branch --show-current)
- Commit: $(git rev-parse HEAD)
- Commit short: $(git rev-parse --short HEAD)
- Runtime alignment status: ${ALIGNMENT_STATUS}

## Open these first

- [Closeout README](README.md)
- [Current full-stack snapshot](reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md)
- [Live runtime alignment](reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md)
- [Founder/operator evidence pack](reports/full_stack_evidence_pack_latest/MANIFEST.md)
- [Grant/visibility pack](reports/grant_visibility_pack_latest/MANIFEST.md)

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

cat > "${OUT_DIR}/README.md" <<'EOF'
# YNX Executive Closeout Pack

Recommended open order:

1. `MANIFEST.md`
2. `reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md`
3. `reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md`
4. `reports/full_stack_evidence_pack_latest/MANIFEST.md`
5. `reports/grant_visibility_pack_latest/MANIFEST.md`
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
