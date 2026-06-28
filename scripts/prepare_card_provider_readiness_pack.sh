#!/usr/bin/env bash
set -euo pipefail

RUN_DOCS=1
RUN_CAPABILITY_AUDIT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-docs)
      RUN_DOCS=0
      shift
      ;;
    --skip-capability-audit)
      RUN_CAPABILITY_AUDIT=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  scripts/prepare_card_provider_readiness_pack.sh [--skip-docs] [--skip-capability-audit]

Generate a provider-facing YNX Card readiness pack with current mock logic,
compliance boundary, capability audit, and provider-integration checklist.
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
OUT_DIR="${OUTPUT_BASE}/card_provider_readiness_pack_${STAMP_LOCAL}"
LATEST_DIR="${OUTPUT_BASE}/card_provider_readiness_pack_latest"

mkdir -p "${OUT_DIR}/docs/en" "${OUT_DIR}/docs/zh" "${OUT_DIR}/reports" "${OUT_DIR}/infra/openapi"

if [[ "${RUN_DOCS}" -eq 1 ]]; then
  bash ./scripts/verify_docs_readiness.sh >/dev/null
fi
if [[ "${RUN_CAPABILITY_AUDIT}" -eq 1 ]]; then
  bash ./scripts/prepare_full_stack_capability_audit.sh --skip-snapshot >/dev/null
fi

declare -a COPY_FILES=(
  "README.md"
  "docs/en/YNX_CARD_PROVIDER_READINESS_PACKET_2026_06_28.md"
  "docs/zh/YNX_Card_服务商对接准备包_2026_06_28.md"
  "docs/en/YNX_CARD_PROVIDER_GO_LIVE_GATES_2026_06_28.md"
  "docs/zh/YNX_Card_服务商上线门禁_2026_06_28.md"
  "docs/en/YNX_CARD_MOCK.md"
  "docs/zh/YNX_Card_Mock_说明.md"
  "docs/en/YNX_CARD_MOCK_DEMO.md"
  "docs/zh/YNX_Card_Mock_演示.md"
  "docs/en/AI_AGENT_SPENDING.md"
  "docs/zh/AI_Agent_Spending_说明.md"
  "docs/en/YNX_FULL_STACK_TRUTH_MATRIX_2026_06_27.md"
  "docs/zh/YNX_全栈真相矩阵_2026_06_27.md"
  "docs/en/COMPLIANCE_READINESS_PACKET_2026_06_13.md"
  "docs/zh/合规就绪包_2026_06_13.md"
  "docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md"
  "docs/zh/YNX_非托管商业与合规边界.md"
  "docs/en/MAINNET_AND_INDUSTRY_READINESS_GATES.md"
  "docs/zh/主网与行业级上线门禁.md"
  "docs/en/YNX_v2_WEB4_API.md"
  "docs/zh/YNX_v2_WEB4_API_接口说明.md"
  "infra/openapi/ynx-v2-web4.yaml"
)

for file in "${COPY_FILES[@]}"; do
  mkdir -p "${OUT_DIR}/$(dirname "${file}")"
  cp "${file}" "${OUT_DIR}/${file}"
done

cp -R "${OUTPUT_BASE}/full_stack_capability_audit_latest" "${OUT_DIR}/reports/"
cp -R "${OUTPUT_BASE}/full_stack_evidence_pack_latest" "${OUT_DIR}/reports/" 2>/dev/null || true

cat > "${OUT_DIR}/MANIFEST.md" <<EOF
# YNX Card Provider Readiness Pack

- Generated: ${NOW_UTC}
- Branch: $(git branch --show-current)
- Commit: $(git rev-parse HEAD)
- Commit short: $(git rev-parse --short HEAD)

## Open these first

- [Provider readiness packet](docs/en/YNX_CARD_PROVIDER_READINESS_PACKET_2026_06_28.md)
- [Provider go-live gates](docs/en/YNX_CARD_PROVIDER_GO_LIVE_GATES_2026_06_28.md)
- [Current capability audit](reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md)
- [YNX Card Mock](docs/en/YNX_CARD_MOCK.md)
- [YNX Card Mock Demo](docs/en/YNX_CARD_MOCK_DEMO.md)
- [AI Agent Spending](docs/en/AI_AGENT_SPENDING.md)
- [Compliance boundary](docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md)
- [Web4 OpenAPI](infra/openapi/ynx-v2-web4.yaml)

## Included docs

EOF

for file in "${COPY_FILES[@]}"; do
  echo "- ${file}" >> "${OUT_DIR}/MANIFEST.md"
done

cat > "${OUT_DIR}/PROVIDER_CHECKLIST.md" <<'EOF'
# Provider Checklist

- [ ] Confirm whether provider can support programmable authorization constraints
- [ ] Confirm MCC / merchant / country filter support model
- [ ] Confirm limit-enforcement model (issuer-native vs shadow control layer)
- [ ] Confirm sandbox prerequisites (KYB, legal, contracts)
- [ ] Confirm PCI / cardholder-data scope ownership
- [ ] Confirm dispute / refund / reconciliation workflow ownership
- [ ] Confirm reference-id mapping between provider events and YNX audit events
EOF

cat > "${OUT_DIR}/README.md" <<'EOF'
# YNX Card Provider Readiness Pack

Recommended open order:

1. `MANIFEST.md`
2. `docs/en/YNX_CARD_PROVIDER_READINESS_PACKET_2026_06_28.md`
3. `docs/en/YNX_CARD_PROVIDER_GO_LIVE_GATES_2026_06_28.md`
4. `reports/full_stack_capability_audit_latest/FULL_STACK_CAPABILITY_AUDIT.md`
5. `docs/en/YNX_CARD_MOCK.md`
6. `docs/en/YNX_CARD_MOCK_DEMO.md`
7. `docs/en/AI_AGENT_SPENDING.md`
8. `docs/en/NON_CUSTODIAL_BUSINESS_AND_COMPLIANCE_BOUNDARY.md`
9. `infra/openapi/ynx-v2-web4.yaml`
10. `PROVIDER_CHECKLIST.md`
11. `SHA256SUMS.txt`
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
  tar -czf "card_provider_readiness_pack_${STAMP_LOCAL}.tar.gz" "card_provider_readiness_pack_${STAMP_LOCAL}"
)

echo "Card provider readiness pack ready:"
echo "- Folder: ${OUT_DIR}"
echo "- Archive: ${OUTPUT_BASE}/card_provider_readiness_pack_${STAMP_LOCAL}.tar.gz"
echo "Stable latest card provider readiness pack:"
echo "- Folder: ${LATEST_DIR}"
