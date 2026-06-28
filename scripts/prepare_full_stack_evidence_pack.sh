#!/usr/bin/env bash
set -euo pipefail

RUN_DOCS=1
RUN_SNAPSHOT=1
RUN_ALIGNMENT=1
RUN_BRIDGE_PACKET=1
RUN_ROLLOUT_PACKET=1
RUN_CAPABILITY_AUDIT=1
RUN_CARD_PROVIDER_PACK=1
RUN_BUILDER_PACK=1

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
    --skip-bridge-packet)
      RUN_BRIDGE_PACKET=0
      shift
      ;;
    --skip-rollout-packet)
      RUN_ROLLOUT_PACKET=0
      shift
      ;;
    --skip-capability-audit)
      RUN_CAPABILITY_AUDIT=0
      shift
      ;;
    --skip-card-provider-pack)
      RUN_CARD_PROVIDER_PACK=0
      shift
      ;;
    --skip-builder-pack)
      RUN_BUILDER_PACK=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_full_stack_evidence_pack.sh [--skip-docs] [--skip-snapshot] [--skip-alignment] [--skip-bridge-packet] [--skip-rollout-packet] [--skip-capability-audit] [--skip-card-provider-pack] [--skip-builder-pack]

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
OUT_DIR="${OUTPUT_BASE}/full_stack_evidence_pack_${STAMP_LOCAL}"
LATEST_DIR="${OUTPUT_BASE}/full_stack_evidence_pack_latest"

mkdir -p "${OUT_DIR}/docs/en" "${OUT_DIR}/docs/zh" "${OUT_DIR}/reports"

if [[ "${RUN_DOCS}" -eq 1 ]]; then
  bash ./scripts/verify_docs_readiness.sh
fi
if [[ "${RUN_SNAPSHOT}" -eq 1 ]]; then
  bash ./scripts/current_full_stack_status_snapshot.sh >/dev/null
fi
if [[ "${RUN_ALIGNMENT}" -eq 1 ]]; then
  bash ./scripts/verify_live_runtime_alignment.sh >/dev/null
fi
if [[ "${RUN_BRIDGE_PACKET}" -eq 1 ]]; then
  bash ./scripts/prepare_bridge_blocker_packet.sh >/dev/null
fi
if [[ "${RUN_ROLLOUT_PACKET}" -eq 1 ]]; then
  bash ./scripts/prepare_live_alignment_rollout_packet.sh --reuse-latest >/dev/null
fi
if [[ "${RUN_CAPABILITY_AUDIT}" -eq 1 ]]; then
  bash ./scripts/prepare_full_stack_capability_audit.sh --skip-snapshot >/dev/null
fi
if [[ "${RUN_CARD_PROVIDER_PACK}" -eq 1 ]]; then
  bash ./scripts/prepare_card_provider_readiness_pack.sh --skip-docs --skip-capability-audit >/dev/null
fi
if [[ "${RUN_BUILDER_PACK}" -eq 1 ]]; then
  bash ./scripts/prepare_builder_readiness_pack.sh --skip-docs >/dev/null
fi

declare -a COPY_FILES=(
  "README.md"
  "docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md"
  "docs/en/FINAL_FULL_STACK_HANDOFF_2026_06_27.md"
  "docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md"
  "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md"
  "docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md"
  "docs/en/SECURITY_RESPONSE_POLICY_2026_06_13.md"
  "docs/en/ACCOUNTABILITY_FORENSICS_ENGINE.md"
  "docs/zh/当前全链状态与对齐快照_2026_06_27.md"
  "docs/zh/最终全链交付总览_2026_06_27.md"
  "docs/zh/YNX_全栈真相矩阵_2026_06_27.md"
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
cp -R "${OUTPUT_BASE}/bridge_blocker_packet_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/live_alignment_rollout_packet_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/full_stack_capability_audit_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/card_provider_readiness_pack_latest" "${OUT_DIR}/reports/" 2>/dev/null || true
cp -R "${OUTPUT_BASE}/builder_readiness_pack_latest" "${OUT_DIR}/reports/" 2>/dev/null || true
cp -R "${OUTPUT_BASE}/audience_map_pack_latest" "${OUT_DIR}/reports/" 2>/dev/null || true

LATEST_DOC_REPORT="$(ls -1t "${OUTPUT_BASE}"/docs_verification_report_*.md 2>/dev/null | head -n 1 || true)"
if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cp "${LATEST_DOC_REPORT}" "${OUT_DIR}/reports/"
fi

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

- [Current full-stack snapshot](reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md)
- [Truth matrix](docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md)
- [Live runtime alignment](reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md)
- [Bridge blocker packet](reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md)
- [Live alignment rollout packet](reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md)
- [Capability audit](reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md)
- [Builder readiness pack](reports/builder_readiness_pack_latest/MANIFEST.md)
- [Card provider readiness pack](reports/card_provider_readiness_pack_latest/MANIFEST.md)
- [Audience map pack](reports/audience_map_pack_latest/MANIFEST.md)
EOF

if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cat >> "${OUT_DIR}/MANIFEST.md" <<EOF
- [Docs verification report](reports/${DOC_REPORT_BASENAME})
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

cat > "${OUT_DIR}/README.md" <<'EOF'
# YNX Full-Stack Evidence Pack

Open these first:

- `MANIFEST.md`
- `HANDOFF_CHECKLIST.md`
- `reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md`
- `docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md`
- `reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md`
- `reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md`
- `reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md`
- `reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md`
- `reports/builder_readiness_pack_latest/MANIFEST.md`
- `reports/card_provider_readiness_pack_latest/MANIFEST.md`
- `reports/audience_map_pack_latest/MANIFEST.md`
- `SHA256SUMS.txt`
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
  tar -czf "full_stack_evidence_pack_${STAMP_LOCAL}.tar.gz" "full_stack_evidence_pack_${STAMP_LOCAL}"
)

echo "Full-stack evidence pack ready:"
echo "- Folder: ${OUT_DIR}"
echo "- Archive: ${OUTPUT_BASE}/full_stack_evidence_pack_${STAMP_LOCAL}.tar.gz"
echo "Stable latest evidence pack:"
echo "- Folder: ${LATEST_DIR}"
