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
  scripts/prepare_external_launchpad_pack.sh [--skip-docs]

Generate a single external-facing launchpad pack that routes builders, grant
reviewers, providers, operators, community readers, and compliance reviewers
to the correct latest truthful packet.
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
OUT_DIR="${OUTPUT_BASE}/external_launchpad_pack_${STAMP_LOCAL}"
LATEST_DIR="${OUTPUT_BASE}/external_launchpad_pack_latest"

mkdir -p "${OUT_DIR}/docs/en" "${OUT_DIR}/docs/zh" "${OUT_DIR}/reports"

if [[ "${RUN_DOCS}" -eq 1 ]]; then
  bash ./scripts/verify_docs_readiness.sh >/dev/null
fi

declare -a COPY_FILES=(
  "README.md"
  "START_HERE_FOR_SUPPORT.md"
  "docs/en/YNX_EXTERNAL_LAUNCHPAD_2026_06_28.md"
  "docs/zh/YNX_对外统一入口_2026_06_28.md"
  "docs/en/YNX_AUDIENCE_MAP_2026_06_28.md"
  "docs/zh/YNX_受众地图_2026_06_28.md"
  "docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md"
  "docs/zh/YNX_全栈真相矩阵_2026_06_27.md"
  "docs/en/X_TELEGRAM_OUTREACH_KIT_2026_06_27.md"
  "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md"
  "docs/en/YNX_CARD_PROVIDER_READINESS_PACKET_2026_06_28.md"
  "docs/en/BUILDER_QUICKSTART.md"
)

for file in "${COPY_FILES[@]}"; do
  mkdir -p "${OUT_DIR}/$(dirname "${file}")"
  cp "${file}" "${OUT_DIR}/${file}"
done

for report_dir in \
  builder_readiness_pack_latest \
  audience_map_pack_latest \
  grant_visibility_pack_latest \
  card_provider_readiness_pack_latest \
  full_stack_evidence_pack_latest \
  executive_closeout_pack_latest \
  current_full_stack_status_latest \
  full_stack_capability_audit_latest; do
  cp -R "${OUTPUT_BASE}/${report_dir}" "${OUT_DIR}/reports/" 2>/dev/null || true
done

cat > "${OUT_DIR}/MANIFEST.md" <<EOF
# YNX External Launchpad Pack

- Generated: ${NOW_UTC}
- Branch: $(git branch --show-current)
- Commit: $(git rev-parse HEAD)
- Commit short: $(git rev-parse --short HEAD)

## Open these first

- [External launchpad](docs/en/YNX_EXTERNAL_LAUNCHPAD_2026_06_28.md)
- [Audience map](docs/en/YNX_AUDIENCE_MAP_2026_06_28.md)
- [Truth matrix](docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md)
- [Builder readiness pack](reports/builder_readiness_pack_latest/MANIFEST.md)
- [Grant visibility pack](reports/grant_visibility_pack_latest/MANIFEST.md)
- [Card provider readiness pack](reports/card_provider_readiness_pack_latest/MANIFEST.md)
- [Full-stack evidence pack](reports/full_stack_evidence_pack_latest/MANIFEST.md)
- [Executive closeout pack](reports/executive_closeout_pack_latest/MANIFEST.md)

## Included docs

EOF

for file in "${COPY_FILES[@]}"; do
  echo "- ${file}" >> "${OUT_DIR}/MANIFEST.md"
done

cat > "${OUT_DIR}/README.md" <<'EOF'
# YNX External Launchpad Pack

Recommended open order:

1. `MANIFEST.md`
2. `docs/en/YNX_EXTERNAL_LAUNCHPAD_2026_06_28.md`
3. `docs/en/YNX_AUDIENCE_MAP_2026_06_28.md`
4. `docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md`
5. `reports/builder_readiness_pack_latest/MANIFEST.md`
6. `reports/grant_visibility_pack_latest/MANIFEST.md`
7. `reports/card_provider_readiness_pack_latest/MANIFEST.md`
8. `reports/full_stack_evidence_pack_latest/MANIFEST.md`
9. `reports/executive_closeout_pack_latest/MANIFEST.md`
10. `SHA256SUMS.txt`
EOF

(
  cd "${OUT_DIR}"
  find . -type f ! -name 'SHA256SUMS.txt' -print0 | sort -z | xargs -0 ${HASH_CMD} > SHA256SUMS.txt
)

TMP_LATEST_DIR="${LATEST_DIR}.tmp.$$"
OLD_LATEST_DIR="${LATEST_DIR}.old.$$"
rm -rf "${TMP_LATEST_DIR}" "${OLD_LATEST_DIR}" 2>/dev/null || true
mkdir -p "${TMP_LATEST_DIR}"
cp -R "${OUT_DIR}/." "${TMP_LATEST_DIR}/"
if [[ -e "${LATEST_DIR}" ]]; then
  mv "${LATEST_DIR}" "${OLD_LATEST_DIR}"
fi
mv "${TMP_LATEST_DIR}" "${LATEST_DIR}"
rm -rf "${OLD_LATEST_DIR}" 2>/dev/null || true

(
  cd "${OUTPUT_BASE}"
  tar -czf "external_launchpad_pack_${STAMP_LOCAL}.tar.gz" "external_launchpad_pack_${STAMP_LOCAL}"
)

echo "External launchpad pack ready:"
echo "- Folder: ${OUT_DIR}"
echo "- Archive: ${OUTPUT_BASE}/external_launchpad_pack_${STAMP_LOCAL}.tar.gz"
echo "Stable latest external launchpad pack:"
echo "- Folder: ${LATEST_DIR}"
