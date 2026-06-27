#!/usr/bin/env bash
set -euo pipefail

RUN_DOCS=1
RUN_SNAPSHOT=1
RUN_ALIGNMENT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-docs)
      RUN_DOCS=0
      shift
      ;;
    --skip-snapshot)
      RUN_SNAPSHOT=0
      shift
      ;;
    --skip-alignment)
      RUN_ALIGNMENT=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_full_stack_evidence_pack.sh [--skip-docs] [--skip-snapshot] [--skip-alignment]

Generate a founder/operator-ready full-stack evidence pack that bundles the
latest live snapshot, runtime alignment audit, and supporting readiness docs
into one stable handoff artifact.
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
OUT_DIR="${OUTPUT_BASE}/full_stack_evidence_pack_${STAMP_LOCAL}"
LATEST_DIR="${OUTPUT_BASE}/full_stack_evidence_pack_latest"

mkdir -p "${OUT_DIR}/docs/en" "${OUT_DIR}/docs/zh" "${OUT_DIR}/reports"

if [[ "${RUN_DOCS}" -eq 1 ]]; then
  ./scripts/verify_docs_readiness.sh
fi
if [[ "${RUN_SNAPSHOT}" -eq 1 ]]; then
  ./scripts/current_full_stack_status_snapshot.sh >/dev/null
fi
if [[ "${RUN_ALIGNMENT}" -eq 1 ]]; then
  ./scripts/verify_live_runtime_alignment.sh >/dev/null
fi

declare -a COPY_FILES=(
  "README.md"
  "docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md"
  "docs/en/FINAL_FULL_STACK_HANDOFF_2026_06_27.md"
  "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md"
  "docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md"
  "docs/en/SECURITY_RESPONSE_POLICY_2026_06_13.md"
  "docs/en/ACCOUNTABILITY_FORENSICS_ENGINE.md"
  "docs/zh/当前全链状态与对齐快照_2026_06_27.md"
  "docs/zh/最终全链交付总览_2026_06_27.md"
  "docs/zh/合规就绪包_2026_06_13.md"
  "docs/zh/主网与行业级上线门禁.md"
  "docs/zh/安全响应策略_2026_06_13.md"
  "docs/zh/问责与取证引擎.md"
)

for file in "${COPY_FILES[@]}"; do
  mkdir -p "${OUT_DIR}/$(dirname "${file}")"
  cp "${file}" "${OUT_DIR}/${file}"
done

cp -R "${OUTPUT_BASE}/current_full_stack_status_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/live_runtime_alignment_latest" "${OUT_DIR}/reports/"

LATEST_DOC_REPORT="$(ls -1t "${OUTPUT_BASE}"/docs_verification_report_*.md 2>/dev/null | head -n 1 || true)"
if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cp "${LATEST_DOC_REPORT}" "${OUT_DIR}/reports/"
fi

CURRENT_SNAPSHOT_MD="${OUT_DIR}/reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md"
CURRENT_ALIGN_MD="${OUT_DIR}/reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md"
DOC_REPORT_BASENAME="$(basename "${LATEST_DOC_REPORT:-}")"
ALIGNMENT_STATUS="$(jq -r '.overall_status' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "UNKNOWN")"
BRIDGE_FULL_LOOP="$(jq -r '.findings[] | select(.id=="bridge_truth") | .detail' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "")"

cat > "${OUT_DIR}/MANIFEST.md" <<EOF
# YNX Full-Stack Evidence Pack

- Generated: ${NOW_UTC}
- Branch: $(git branch --show-current)
- Commit: $(git rev-parse HEAD)
- Commit short: $(git rev-parse --short HEAD)
- Alignment status: ${ALIGNMENT_STATUS}

## Included stable reports

- [Current full-stack snapshot](${CURRENT_SNAPSHOT_MD})
- [Live runtime alignment](${CURRENT_ALIGN_MD})
EOF

if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cat >> "${OUT_DIR}/MANIFEST.md" <<EOF
- [Docs verification report](${OUT_DIR}/reports/${DOC_REPORT_BASENAME})
EOF
fi

cat >> "${OUT_DIR}/MANIFEST.md" <<EOF

## Current truth at pack generation time

- Bridge alignment summary: ${BRIDGE_FULL_LOOP}
- Stable latest runtime evidence is bundled so founder/operator handoff does
  not depend on time-stamped paths.

## Included docs

EOF

for file in "${COPY_FILES[@]}"; do
  echo "- ${file}" >> "${OUT_DIR}/MANIFEST.md"
done

cat > "${OUT_DIR}/HANDOFF_CHECKLIST.md" <<'EOF'
# Handoff Checklist

- [ ] Review current full-stack snapshot
- [ ] Review live runtime alignment report
- [ ] Review current bridge blockers
- [ ] Review compliance readiness packet
- [ ] Review mainnet and industry readiness gates
- [ ] Review security response policy
- [ ] Use this pack as the founder/operator reference before external outreach
EOF

rm -rf "${LATEST_DIR}"
mkdir -p "${LATEST_DIR}"
cp -R "${OUT_DIR}/." "${LATEST_DIR}/"

(
  cd "${OUTPUT_BASE}"
  tar -czf "full_stack_evidence_pack_${STAMP_LOCAL}.tar.gz" "full_stack_evidence_pack_${STAMP_LOCAL}"
)

echo "Full-stack evidence pack ready:"
echo "- Folder: ${OUT_DIR}"
echo "- Archive: ${OUTPUT_BASE}/full_stack_evidence_pack_${STAMP_LOCAL}.tar.gz"
echo "Stable latest evidence pack:"
echo "- Folder: ${LATEST_DIR}"
