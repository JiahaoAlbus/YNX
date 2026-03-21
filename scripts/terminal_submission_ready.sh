#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

RUN_VERIFY=1
RUN_PACK=1

FOUNDER_NAME="${FOUNDER_NAME:-}"
SECURITY_EMAIL="${SECURITY_EMAIL:-}"
OPS_EMAIL="${OPS_EMAIL:-}"
CONTACT_TIMEZONE="${CONTACT_TIMEZONE:-Asia/Shanghai}"
AUDIT_WINDOW="${AUDIT_WINDOW:-}"
BUDGET_MODE="${BUDGET_MODE:-}"
DISCLOSURE_MODE="${DISCLOSURE_MODE:-}"
RETEST_REQUIRED="${RETEST_REQUIRED:-yes}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/terminal_submission_ready.sh [options]

Options:
  --founder-name <name>
  --security-email <email>
  --ops-email <email>
  --timezone <tz>
  --audit-window <text>
  --budget-mode <text>
  --disclosure <public|private>
  --retest <yes|no>
  --skip-verify
  --skip-pack
  -h, --help

Example:
  ./scripts/terminal_submission_ready.sh \
    --founder-name "Jiahao" \
    --security-email "security@ynxweb4.com" \
    --ops-email "ops@ynxweb4.com" \
    --timezone "Asia/Shanghai" \
    --audit-window "2026-04 (2 weeks)" \
    --budget-mode "fixed bid" \
    --disclosure "public" \
    --retest "yes"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --founder-name) FOUNDER_NAME="${2:-}"; shift 2 ;;
    --security-email) SECURITY_EMAIL="${2:-}"; shift 2 ;;
    --ops-email) OPS_EMAIL="${2:-}"; shift 2 ;;
    --timezone) CONTACT_TIMEZONE="${2:-}"; shift 2 ;;
    --audit-window) AUDIT_WINDOW="${2:-}"; shift 2 ;;
    --budget-mode) BUDGET_MODE="${2:-}"; shift 2 ;;
    --disclosure) DISCLOSURE_MODE="${2:-}"; shift 2 ;;
    --retest) RETEST_REQUIRED="${2:-}"; shift 2 ;;
    --skip-verify) RUN_VERIFY=0; shift ;;
    --skip-pack) RUN_PACK=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

prompt_if_empty() {
  local var_name="$1"
  local prompt_text="$2"
  local current="${!var_name}"
  if [[ -n "${current}" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    echo "Missing required value for ${var_name} in non-interactive mode." >&2
    exit 1
  fi
  read -r -p "${prompt_text}: " current
  if [[ -z "${current}" ]]; then
    echo "${var_name} cannot be empty." >&2
    exit 1
  fi
  printf -v "${var_name}" "%s" "${current}"
}

prompt_if_empty FOUNDER_NAME "Founder / project owner"
prompt_if_empty SECURITY_EMAIL "Security contact email"
prompt_if_empty OPS_EMAIL "Ops contact email"
prompt_if_empty CONTACT_TIMEZONE "Contact timezone (e.g. Asia/Shanghai)"
prompt_if_empty AUDIT_WINDOW "Preferred audit window"
prompt_if_empty BUDGET_MODE "Budget mode (fixed bid / T&M / contest)"
prompt_if_empty DISCLOSURE_MODE "Report disclosure mode (public/private)"
prompt_if_empty RETEST_REQUIRED "Need retest (yes/no)"

if [[ "${RUN_VERIFY}" -eq 1 ]]; then
  ./scripts/verify_submission_readiness.sh
fi

if [[ "${RUN_PACK}" -eq 1 ]]; then
  ./scripts/prepare_audit_compliance_pack.sh
fi

PACK_DIR="$(find "${REPO_ROOT}/output" -maxdepth 1 -type d -name 'audit_compliance_pack_*' | sort | tail -n 1)"
if [[ -z "${PACK_DIR}" ]]; then
  echo "No audit_compliance_pack directory found under output/." >&2
  exit 1
fi

PROFILE_DIR="${PACK_DIR}/submission_profile"
mkdir -p "${PROFILE_DIR}"

STAMP_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

cat > "${PROFILE_DIR}/FORM_FIELDS.env" <<EOF
FOUNDER_NAME="${FOUNDER_NAME}"
SECURITY_EMAIL="${SECURITY_EMAIL}"
OPS_EMAIL="${OPS_EMAIL}"
CONTACT_TIMEZONE="${CONTACT_TIMEZONE}"
AUDIT_WINDOW="${AUDIT_WINDOW}"
BUDGET_MODE="${BUDGET_MODE}"
DISCLOSURE_MODE="${DISCLOSURE_MODE}"
RETEST_REQUIRED="${RETEST_REQUIRED}"
EOF

cat > "${PROFILE_DIR}/FORM_FIELDS.json" <<EOF
{
  "founder_name": "${FOUNDER_NAME}",
  "security_email": "${SECURITY_EMAIL}",
  "ops_email": "${OPS_EMAIL}",
  "contact_timezone": "${CONTACT_TIMEZONE}",
  "audit_window": "${AUDIT_WINDOW}",
  "budget_mode": "${BUDGET_MODE}",
  "disclosure_mode": "${DISCLOSURE_MODE}",
  "retest_required": "${RETEST_REQUIRED}",
  "generated_at_utc": "${STAMP_UTC}"
}
EOF

cat > "${PROFILE_DIR}/SUBMISSION_PACKET_FILLED_EN.md" <<EOF
# YNX v2 Audit + Compliance Submission Packet (Filled)

- Generated: ${STAMP_UTC}
- Baseline commit: $(git rev-parse HEAD)
- Baseline tag (recommended): ynxweb4-submission-ready-20260321

## Contact Block

- Founder / project owner: ${FOUNDER_NAME}
- Security contact email: ${SECURITY_EMAIL}
- Ops contact email: ${OPS_EMAIL}
- Timezone for live sync: ${CONTACT_TIMEZONE}

## Commercial Block

- Preferred audit window: ${AUDIT_WINDOW}
- Preferred delivery mode: ${BUDGET_MODE}
- Report disclosure model: ${DISCLOSURE_MODE}
- Need retest included: ${RETEST_REQUIRED}

## Canonical references

- docs/en/V2_AUDIT_SUBMISSION_PACKET.md
- docs/en/V2_PLATFORM_SUBMISSION_PLAYBOOK.md
- output/docs_verification_report_*.md
- output/runtime_evidence_*/RUNTIME_EVIDENCE.md
EOF

cat > "${PROFILE_DIR}/提交包_已填写_中文.md" <<EOF
# YNX v2 审计与合规提交包（已填写）

- 生成时间：${STAMP_UTC}
- 基线提交：$(git rev-parse HEAD)
- 建议基线标签：ynxweb4-submission-ready-20260321

## 联系信息

- 项目负责人：${FOUNDER_NAME}
- 安全联系人邮箱：${SECURITY_EMAIL}
- 运维联系人邮箱：${OPS_EMAIL}
- 时区与可沟通时间：${CONTACT_TIMEZONE}

## 商务信息

- 期望审计窗口：${AUDIT_WINDOW}
- 预算模式：${BUDGET_MODE}
- 报告公开策略：${DISCLOSURE_MODE}
- 是否需要复测：${RETEST_REQUIRED}

## 参考材料

- docs/zh/V2_审计与合规提交包.md
- docs/zh/V2_平台提交流程手册.md
- output/docs_verification_report_*.md
- output/runtime_evidence_*/RUNTIME_EVIDENCE.md
EOF

cat > "${PROFILE_DIR}/NEXT_STEP_CHECKLIST.md" <<'EOF'
# Next Step Checklist

- [ ] Upload or reference SUBMISSION_PACKET_FILLED_EN.md
- [ ] Upload or reference 提交包_已填写_中文.md (if CN workflow needed)
- [ ] Attach latest docs verification report
- [ ] Attach latest runtime evidence report
- [ ] Provide repository URL and baseline tag
- [ ] Submit to selected audit vendors
- [ ] Submit to compliance automation platform + auditor
EOF

echo "Terminal submission package ready:"
echo "- Pack directory: ${PACK_DIR}"
echo "- Filled profile: ${PROFILE_DIR}"
echo "- EN packet: ${PROFILE_DIR}/SUBMISSION_PACKET_FILLED_EN.md"
echo "- ZH packet: ${PROFILE_DIR}/提交包_已填写_中文.md"
echo "- Env fields: ${PROFILE_DIR}/FORM_FIELDS.env"
