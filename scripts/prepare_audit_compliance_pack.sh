#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

SKIP_DOC_CHECKS=0
SKIP_RUNTIME_EVIDENCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-doc-checks)
      SKIP_DOC_CHECKS=1
      shift
      ;;
    --skip-runtime-evidence)
      SKIP_RUNTIME_EVIDENCE=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "${SKIP_DOC_CHECKS}" -eq 0 ]]; then
  ./scripts/verify_docs_readiness.sh
fi

STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
OUT_BASE="${REPO_ROOT}/output/audit_compliance_pack_${STAMP_LOCAL}"
DOCS_DIR="${OUT_BASE}/docs"
REPORTS_DIR="${OUT_BASE}/reports"
mkdir -p "${DOCS_DIR}" "${REPORTS_DIR}"

declare -a REQUIRED_FILES=(
  "README.md"
  "SECURITY.md"
  "docs/en/INDEX.md"
  "docs/zh/INDEX.md"
  "docs/en/RELEASE_YNXWEB4.md"
  "docs/zh/YNXWEB4_版本说明.md"
  "docs/en/YNX_v2_WEB4_SPEC.md"
  "docs/en/YNX_v2_WEB4_API.md"
  "docs/en/YNX_v2_AI_SETTLEMENT_API.md"
  "docs/en/V2_SECURITY_MODEL.md"
  "docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md"
  "docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md"
  "docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md"
  "docs/zh/V2_公开测试网加入手册.md"
  "docs/zh/V2_验证节点加入手册.md"
  "docs/zh/V2_共识验证人加入手册.md"
  "docs/en/V2_AUDIT_COMPLIANCE_EXECUTION_GUIDE.md"
  "docs/en/V2_AUDIT_SUBMISSION_PACKET.md"
  "docs/en/V2_PLATFORM_SUBMISSION_PLAYBOOK.md"
  "docs/zh/V2_安全审计与合规执行指南.md"
  "docs/zh/V2_审计与合规提交包.md"
  "docs/zh/V2_平台提交流程手册.md"
  "infra/openapi/ynx-v2-ai.yaml"
  "infra/openapi/ynx-v2-web4.yaml"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -r "${REPO_ROOT}/${file}" ]]; then
    echo "Missing required file: ${file}" >&2
    exit 1
  fi
  target_dir="${DOCS_DIR}/$(dirname "${file}")"
  mkdir -p "${target_dir}"
  cp "${REPO_ROOT}/${file}" "${target_dir}/"
done

LATEST_DOC_REPORT="$(ls -1t "${REPO_ROOT}"/output/docs_verification_report_*.md 2>/dev/null | head -n 1 || true)"
if [[ -n "${LATEST_DOC_REPORT}" ]]; then
  cp "${LATEST_DOC_REPORT}" "${REPORTS_DIR}/"
fi

RUNTIME_EVIDENCE_REPORT=""
if [[ "${SKIP_RUNTIME_EVIDENCE}" -eq 0 ]]; then
  ./scripts/capture_public_runtime_evidence.sh
  RUNTIME_EVIDENCE_REPORT="$(ls -1t "${REPO_ROOT}"/output/runtime_evidence_*/RUNTIME_EVIDENCE.md 2>/dev/null | head -n 1 || true)"
  if [[ -n "${RUNTIME_EVIDENCE_REPORT}" ]]; then
    RUNTIME_EVIDENCE_DIR="$(dirname "${RUNTIME_EVIDENCE_REPORT}")"
    cp -R "${RUNTIME_EVIDENCE_DIR}" "${REPORTS_DIR}/"
  fi
fi

{
  echo "# YNX Submission Answers (Copy-Paste)"
  echo
  echo "- Project: YNX"
  echo "- Category: L1 public execution network (AI-native Web4 track)"
  echo "- Positioning: Sovereign Execution Layer"
  echo "- Repository: https://github.com/JiahaoAlbus/YNX"
  echo "- Track: v2-web4"
  echo "- Cosmos Chain ID: ynx_9102-1"
  echo "- EVM Chain ID: 0x238e (9102)"
  echo "- Denom: anyxt"
  echo "- RPC: https://rpc.ynxweb4.com"
  echo "- EVM RPC: https://evm.ynxweb4.com"
  echo "- Faucet: https://faucet.ynxweb4.com"
  echo "- Indexer: https://indexer.ynxweb4.com"
  echo "- Explorer: https://explorer.ynxweb4.com"
  echo "- AI Gateway: https://ai.ynxweb4.com"
  echo "- Web4 Hub: https://web4.ynxweb4.com"
  echo "- Scope baseline commit: $(git rev-parse HEAD)"
  echo "- Scope baseline tag candidate: ynxweb4-audit-compliance-prep-$(date +%Y%m%d)"
} > "${OUT_BASE}/SUBMISSION_ANSWERS.md"

{
  echo "# YNX Audit + Compliance Pack Manifest"
  echo
  echo "- Generated: ${NOW_UTC}"
  echo "- Repository: ${REPO_ROOT}"
  echo "- Branch: $(git branch --show-current)"
  echo "- Commit: $(git rev-parse HEAD)"
  echo "- Commit (short): $(git rev-parse --short HEAD)"
  echo "- Latest tag reachable: $(git describe --tags --abbrev=0 2>/dev/null || echo 'none')"
  echo
  echo "## Included files"
  for file in "${REQUIRED_FILES[@]}"; do
    echo "- ${file}"
  done
  echo
  if [[ -n "${LATEST_DOC_REPORT}" ]]; then
    echo "## Included report"
    echo "- $(basename "${LATEST_DOC_REPORT}")"
  fi
  if [[ -n "${RUNTIME_EVIDENCE_REPORT}" ]]; then
    echo "- runtime evidence: $(basename "$(dirname "${RUNTIME_EVIDENCE_REPORT}")")/RUNTIME_EVIDENCE.md"
  fi
  echo
  echo "## Next actions (manual fill)"
  echo "- Fill contact and commercial fields in:"
  echo "  - docs/en/V2_AUDIT_SUBMISSION_PACKET.md"
  echo "  - docs/zh/V2_审计与合规提交包.md"
  echo "- Select audit vendors and submit the same tagged scope packet."
  echo "- Start compliance tool onboarding (Drata/Vanta/Secureframe) and auditor onboarding."
  echo "- Use SUBMISSION_ANSWERS.md for direct platform form copy-paste."
} > "${OUT_BASE}/MANIFEST.md"

{
  echo "# External Form Copy-Paste Checklist"
  echo
  echo "- [ ] Founder / owner contact filled"
  echo "- [ ] Security contact email filled"
  echo "- [ ] Preferred audit window filled"
  echo "- [ ] Budget mode selected"
  echo "- [ ] Report disclosure preference selected"
  echo "- [ ] Submission tag created and pushed"
  echo "- [ ] Verify/smoke evidence attached"
  echo "- [ ] Docs readiness report attached"
} > "${OUT_BASE}/FORM_CHECKLIST.md"

(
  cd "${REPO_ROOT}/output"
  tar -czf "audit_compliance_pack_${STAMP_LOCAL}.tar.gz" "audit_compliance_pack_${STAMP_LOCAL}"
)

echo "Audit/compliance pack ready:"
echo "- Folder: ${OUT_BASE}"
echo "- Archive: ${REPO_ROOT}/output/audit_compliance_pack_${STAMP_LOCAL}.tar.gz"
