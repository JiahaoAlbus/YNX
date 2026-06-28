#!/usr/bin/env bash
set -euo pipefail

RUN_DOCS=1
RUN_CARD_DEMO=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-docs)
      RUN_DOCS=0
      shift
      ;;
    --skip-card-demo)
      RUN_CARD_DEMO=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_builder_readiness_pack.sh [--skip-docs] [--skip-card-demo]

Generate a builder-facing pack for the live public-testnet developer surfaces:
EVM, Web4 Hub, AI Gateway, trace/indexer, and local demo entrypoints.
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
OUT_DIR="${OUTPUT_BASE}/builder_readiness_pack_${STAMP_LOCAL}"
LATEST_DIR="${OUTPUT_BASE}/builder_readiness_pack_latest"

mkdir -p "${OUT_DIR}/docs/en" "${OUT_DIR}/infra/openapi" "${OUT_DIR}/reports"

if [[ "${RUN_DOCS}" -eq 1 ]]; then
  bash ./scripts/verify_docs_readiness.sh >/dev/null
fi
if [[ "${RUN_CARD_DEMO}" -eq 1 ]]; then
  bash ./scripts/ynx_card_mock_demo.sh >/dev/null
fi

declare -a COPY_FILES=(
  "README.md"
  "docs/en/BUILDER_QUICKSTART.md"
  "docs/en/YNX_v2_WEB4_API.md"
  "docs/en/YNX_v2_AI_SETTLEMENT_API.md"
  "docs/en/AI_WEB4_OFFICIAL_DEMO.md"
  "docs/en/YNX_CARD_MOCK_DEMO.md"
  "docs/en/ACCOUNTABILITY_FORENSICS_ENGINE.md"
  "docs/en/PUBLIC_ASSET_STATUS.md"
  "infra/openapi/ynx-v2-ai.yaml"
  "infra/openapi/ynx-v2-web4.yaml"
)

for file in "${COPY_FILES[@]}"; do
  mkdir -p "${OUT_DIR}/$(dirname "${file}")"
  cp "${file}" "${OUT_DIR}/${file}"
done

for report_dir in \
  current_full_stack_status_latest \
  full_stack_capability_audit_latest \
  full_stack_evidence_pack_latest \
  ynx_card_demo_latest; do
  cp -R "${OUTPUT_BASE}/${report_dir}" "${OUT_DIR}/reports/" 2>/dev/null || true
done

cat > "${OUT_DIR}/MANIFEST.md" <<EOF
# YNX Builder Readiness Pack

- Generated: ${NOW_UTC}
- Branch: $(git branch --show-current)
- Commit: $(git rev-parse HEAD)
- Commit short: $(git rev-parse --short HEAD)

## Open these first

- [Builder quickstart](docs/en/BUILDER_QUICKSTART.md)
- [Web4 API](docs/en/YNX_v2_WEB4_API.md)
- [AI settlement API](docs/en/YNX_v2_AI_SETTLEMENT_API.md)
- [Latest YNX Card demo evidence](reports/ynx_card_demo_latest/README.md)
- [Current full-stack snapshot](reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md)
- [Capability audit](reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md)

## Included docs

EOF

for file in "${COPY_FILES[@]}"; do
  echo "- ${file}" >> "${OUT_DIR}/MANIFEST.md"
done

cat > "${OUT_DIR}/README.md" <<'EOF'
# YNX Builder Readiness Pack

Recommended open order:

1. `MANIFEST.md`
2. `docs/en/BUILDER_QUICKSTART.md`
3. `docs/en/YNX_v2_WEB4_API.md`
4. `docs/en/YNX_v2_AI_SETTLEMENT_API.md`
5. `docs/en/AI_WEB4_OFFICIAL_DEMO.md`
6. `reports/ynx_card_demo_latest/README.md`
7. `reports/current_full_stack_status_latest/CURRENT_FULL_STACK_STATUS.md`
8. `reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md`
9. `SHA256SUMS.txt`
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
  tar -czf "builder_readiness_pack_${STAMP_LOCAL}.tar.gz" "builder_readiness_pack_${STAMP_LOCAL}"
)

echo "Builder readiness pack ready:"
echo "- Folder: ${OUT_DIR}"
echo "- Archive: ${OUTPUT_BASE}/builder_readiness_pack_${STAMP_LOCAL}.tar.gz"
echo "Stable latest builder readiness pack:"
echo "- Folder: ${LATEST_DIR}"
