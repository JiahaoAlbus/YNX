#!/usr/bin/env bash
set -euo pipefail

RUN_DOCS=1
RUN_SNAPSHOT=1
RUN_EVIDENCE_PACK=1

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
    --skip-evidence-pack)
      RUN_EVIDENCE_PACK=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_grant_visibility_pack.sh [--skip-docs] [--skip-snapshot] [--skip-evidence-pack]

Generate a truthful outward-facing grant / visibility pack that bundles the
latest status evidence, grant targets, application templates, outreach copy,
and core diligence/compliance boundary docs.
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
OUT_DIR="${OUTPUT_BASE}/grant_visibility_pack_${STAMP_LOCAL}"
LATEST_DIR="${OUTPUT_BASE}/grant_visibility_pack_latest"

mkdir -p "${OUT_DIR}/docs/en" "${OUT_DIR}/docs/zh" "${OUT_DIR}/reports"

if [[ "${RUN_DOCS}" -eq 1 ]]; then
  bash ./scripts/verify_docs_readiness.sh
fi
if [[ "${RUN_SNAPSHOT}" -eq 1 ]]; then
  bash ./scripts/current_full_stack_status_snapshot.sh >/dev/null
  bash ./scripts/verify_live_runtime_alignment.sh >/dev/null
  bash ./scripts/prepare_bridge_blocker_packet.sh >/dev/null
  bash ./scripts/prepare_live_alignment_rollout_packet.sh --reuse-latest >/dev/null
fi
if [[ "${RUN_EVIDENCE_PACK}" -eq 1 ]]; then
  bash ./scripts/prepare_full_stack_evidence_pack.sh >/dev/null
fi

declare -a COPY_FILES=(
  "README.md"
  "docs/en/GRANT_AND_VISIBILITY_TARGETS_2026_06_27.md"
  "docs/en/GRANT_APPLICATION_KIT_2026_06_27.md"
  "docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md"
  "docs/en/X_TELEGRAM_OUTREACH_KIT_2026_06_27.md"
  "docs/en/INVESTOR_DATA_ROOM_2026_06_13.md"
  "docs/en/FUNDRAISING_MEMO_2026_06_13.md"
  "docs/en/EXTERNAL_RESPONSE_PACK_2026_06_19.md"
  "docs/en/FOLLOW_UP_TEMPLATES_2026_06_19.md"
  "docs/en/CURRENT_FULL_STACK_STATUS_2026_06_27.md"
  "docs/en/FINAL_FULL_STACK_HANDOFF_2026_06_27.md"
  "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md"
  "docs/en/CORE_MOAT_AND_BOUNDARY_2026_06_13.md"
  "docs/en/INVESTOR_HARD_QUESTIONS_2026_06_13.md"
  "docs/zh/Grant与曝光目标清单_2026_06_27.md"
  "docs/zh/Grant申请模板包_2026_06_27.md"
  "docs/zh/YNX_全栈真相矩阵_2026_06_27.md"
  "docs/zh/X与Telegram对外发布素材_2026_06_27.md"
  "docs/zh/投资人与尽调资料室_2026_06_13.md"
  "docs/zh/融资备忘录_2026_06_13.md"
  "docs/zh/对外答复标准包_2026_06_19.md"
  "docs/zh/跟进模板_2026_06_19.md"
  "docs/zh/当前全链状态与对齐快照_2026_06_27.md"
  "docs/zh/最终全链交付总览_2026_06_27.md"
  "docs/zh/合规就绪包_2026_06_13.md"
  "docs/zh/核心护城河与边界_2026_06_13.md"
  "docs/zh/投资人十大尖锐问题_2026_06_13.md"
)

for file in "${COPY_FILES[@]}"; do
  mkdir -p "${OUT_DIR}/$(dirname "${file}")"
  cp "${file}" "${OUT_DIR}/${file}"
done

cp -R "${OUTPUT_BASE}/current_full_stack_status_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/live_runtime_alignment_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/bridge_blocker_packet_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/live_alignment_rollout_packet_latest" "${OUT_DIR}/reports/"
if [[ -d "${OUTPUT_BASE}/full_stack_evidence_pack_latest" ]]; then
  cp -R "${OUTPUT_BASE}/full_stack_evidence_pack_latest" "${OUT_DIR}/reports/"
fi

LATEST_DOC_REPORT="$(ls -1t "${OUTPUT_BASE}"/docs_verification_report_*.md 2>/dev/null | head -n 1 || true)"
if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cp "${LATEST_DOC_REPORT}" "${OUT_DIR}/reports/"
fi

ALIGNMENT_STATUS="$(jq -r '.overall_status' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "UNKNOWN")"
BRIDGE_DETAIL="$(jq -r '.findings[] | select(.id=="bridge_truth") | .detail' "${OUTPUT_BASE}/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.json" 2>/dev/null || echo "")"
VISIBILITY_NOTE="Use the truthful public-testnet infrastructure framing. Do not claim 5/5 bridge completion, production custody, or finished mainnet/legal status."

cat > "${OUT_DIR}/MANIFEST.md" <<EOF
# YNX Grant / Visibility Pack

- Generated: ${NOW_UTC}
- Branch: $(git branch --show-current)
- Commit: $(git rev-parse HEAD)
- Commit short: $(git rev-parse --short HEAD)
- Alignment status: ${ALIGNMENT_STATUS}

## Recommended use

- grant applications
- ecosystem support / funding outreach
- X / Telegram public posts
- investor / diligence intro follow-ups

## Current truth anchor

- Bridge status summary: ${BRIDGE_DETAIL}
- Messaging rule: ${VISIBILITY_NOTE}

## Included reports

- [Latest full-stack snapshot](reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md)
- [Truth matrix](docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md)
- [Latest runtime alignment](reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md)
- [Latest bridge blocker packet](reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md)
- [Latest live alignment rollout packet](reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md)
EOF

if [[ -d "${OUT_DIR}/reports/full_stack_evidence_pack_latest" ]]; then
  cat >> "${OUT_DIR}/MANIFEST.md" <<EOF
- [Latest full-stack evidence pack manifest](reports/full_stack_evidence_pack_latest/MANIFEST.md)
EOF
fi

if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cat >> "${OUT_DIR}/MANIFEST.md" <<EOF
- [Docs verification report](reports/$(basename "${LATEST_DOC_REPORT}"))
EOF
fi

cat >> "${OUT_DIR}/MANIFEST.md" <<EOF

## Included docs

EOF

for file in "${COPY_FILES[@]}"; do
  echo "- ${file}" >> "${OUT_DIR}/MANIFEST.md"
done

cat > "${OUT_DIR}/OUTREACH_CHECKLIST.md" <<'EOF'
# Outreach Checklist

- [ ] Read the latest runtime alignment report before outreach
- [ ] Keep bridge wording at current truthful live status
- [ ] Use grant targets doc to pick the right ecosystem angle
- [ ] Use grant application kit for form answers
- [ ] Use X / Telegram kit for public posting
- [ ] Use diligence / hard-questions docs for follow-up replies
- [ ] Do not imply custody, completed legal sign-off, or finished mainnet
EOF

cat > "${OUT_DIR}/README.md" <<'EOF'
# YNX Grant / Visibility Pack

Open these first:

- `MANIFEST.md`
- `OUTREACH_CHECKLIST.md`
- `reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md`
- `docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md`
- `reports/live_runtime_alignment_latest/LIVE_RUNTIME_ALIGNMENT.md`
- `reports/bridge_blocker_packet_latest/BRIDGE_BLOCKER_PACKET.md`
- `reports/live_alignment_rollout_packet_latest/LIVE_ALIGNMENT_ROLLOUT_PACKET.md`
- `docs/en/GRANT_AND_VISIBILITY_TARGETS_2026_06_27.md`
- `docs/en/X_TELEGRAM_OUTREACH_KIT_2026_06_27.md`
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
  tar -czf "grant_visibility_pack_${STAMP_LOCAL}.tar.gz" "grant_visibility_pack_${STAMP_LOCAL}"
)

echo "Grant / visibility pack ready:"
echo "- Folder: ${OUT_DIR}"
echo "- Archive: ${OUTPUT_BASE}/grant_visibility_pack_${STAMP_LOCAL}.tar.gz"
echo "Stable latest grant / visibility pack:"
echo "- Folder: ${LATEST_DIR}"
