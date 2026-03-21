#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

REPORT_DIR="${REPO_ROOT}/output"
mkdir -p "${REPORT_DIR}"

STAMP_LOCAL="$(date +"%Y%m%d_%H%M%S")"
NOW_UTC="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
REPORT_PATH="${REPORT_DIR}/docs_verification_report_${STAMP_LOCAL}.md"

declare -a CHECK_IDS=()
declare -a CHECK_NAMES=()
declare -a CHECK_STATUS=()
declare -a CHECK_DETAILS=()

PASS_COUNT=0
FAIL_COUNT=0

record_check() {
  local check_id="$1"
  local check_name="$2"
  local status="$3"
  local details="$4"

  CHECK_IDS+=("${check_id}")
  CHECK_NAMES+=("${check_name}")
  CHECK_STATUS+=("${status}")
  CHECK_DETAILS+=("${details}")

  if [[ "${status}" == "PASS" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

search_first_match() {
  local pattern="$1"
  local file="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -n --max-count 1 -e "${pattern}" "${file}" || true
  else
    grep -En -m 1 "${pattern}" "${file}" || true
  fi
}

check_file_exists() {
  local check_id="$1"
  local path="$2"
  if [[ -r "${path}" ]]; then
    local line_count
    line_count="$(wc -l <"${path}" | tr -d ' ')"
    record_check "${check_id}" "File exists: \`${path}\`" "PASS" "readable, lines=${line_count}"
  else
    record_check "${check_id}" "File exists: \`${path}\`" "FAIL" "file missing or unreadable"
  fi
}

check_semantic() {
  local check_id="$1"
  local path="$2"
  local pattern="$3"
  local label="$4"
  local match
  match="$(search_first_match "${pattern}" "${path}")"
  if [[ -n "${match}" ]]; then
    record_check "${check_id}" "Semantic section: \`${path}\`" "PASS" "${label}: ${match}"
  else
    record_check "${check_id}" "Semantic section: \`${path}\`" "FAIL" "${label} pattern not found"
  fi
}

contains_fixed() {
  local file="$1"
  local needle="$2"
  grep -Fq -- "${needle}" "${file}"
}

check_reference_coverage() {
  local failures=()

  local readme="README.md"
  local en_index="docs/en/INDEX.md"
  local zh_index="docs/zh/INDEX.md"
  local en_release="docs/en/RELEASE_YNXWEB4.md"
  local zh_release="docs/zh/YNXWEB4_版本说明.md"

  local en_pub="docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md"
  local en_node="docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md"
  local en_cons="docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md"
  local zh_pub="docs/zh/V2_公开测试网加入手册.md"
  local zh_node="docs/zh/V2_验证节点加入手册.md"
  local zh_cons="docs/zh/V2_共识验证人加入手册.md"

  for needle in "${en_pub}" "${en_node}" "${en_cons}" "${zh_pub}" "${zh_node}" "${zh_cons}"; do
    contains_fixed "${readme}" "${needle}" || failures+=("README missing ${needle}")
  done

  for needle in "${en_pub}" "${en_node}" "${en_cons}"; do
    contains_fixed "${en_index}" "${needle}" || failures+=("docs/en/INDEX.md missing ${needle}")
  done

  for needle in "${zh_pub}" "${zh_node}" "${zh_cons}"; do
    contains_fixed "${zh_index}" "${needle}" || failures+=("docs/zh/INDEX.md missing ${needle}")
  done

  for needle in "${en_pub}" "${en_node}" "${en_cons}" "${zh_pub}" "${zh_node}" "${zh_cons}"; do
    contains_fixed "${en_release}" "${needle}" || failures+=("docs/en/RELEASE_YNXWEB4.md missing ${needle}")
    contains_fixed "${zh_release}" "${needle}" || failures+=("docs/zh/YNXWEB4_版本说明.md missing ${needle}")
  done

  if (( ${#failures[@]} == 0 )); then
    record_check "13" "README/INDEX/RELEASE references coverage" "PASS" "all required guide references found"
  else
    local detail
    detail="$(printf '%s; ' "${failures[@]}")"
    detail="${detail%; }"
    record_check "13" "README/INDEX/RELEASE references coverage" "FAIL" "${detail}"
  fi
}

# 1-6: file existence
check_file_exists "1" "docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md"
check_file_exists "2" "docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md"
check_file_exists "3" "docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md"
check_file_exists "4" "docs/zh/V2_公开测试网加入手册.md"
check_file_exists "5" "docs/zh/V2_验证节点加入手册.md"
check_file_exists "6" "docs/zh/V2_共识验证人加入手册.md"

# 7-12: zero-start semantics
check_semantic "7" "docs/en/V2_PUBLIC_TESTNET_JOIN_GUIDE.md" "from zero|fresh machine|start from zero" "EN zero-start"
check_semantic "8" "docs/en/V2_VALIDATOR_NODE_JOIN_GUIDE.md" "from zero|fresh machine|Prepare environment from zero|start from zero" "EN zero-start"
check_semantic "9" "docs/en/V2_CONSENSUS_VALIDATOR_JOIN_GUIDE.md" "from zero|fresh machine|start from zero" "EN zero-start"
check_semantic "10" "docs/zh/V2_公开测试网加入手册.md" "从零开始|新机器|从零" "ZH zero-start"
check_semantic "11" "docs/zh/V2_验证节点加入手册.md" "从零开始|新机器|从零" "ZH zero-start"
check_semantic "12" "docs/zh/V2_共识验证人加入手册.md" "从零开始|新机器|从零" "ZH zero-start"

# 13: references and release coverage
check_reference_coverage

{
  echo "# YNX Docs Verification Report"
  echo
  echo "- Generated: ${NOW_UTC}"
  echo "- Repository: ${REPO_ROOT}"
  echo "- Total checks: ${#CHECK_IDS[@]}"
  echo "- Passed: ${PASS_COUNT}"
  echo "- Failed: ${FAIL_COUNT}"
  echo
  echo "## Summary"
  echo
  echo "| ID | Check | Status | Details |"
  echo "|---:|---|---|---|"
  for idx in "${!CHECK_IDS[@]}"; do
    id="${CHECK_IDS[$idx]}"
    name="${CHECK_NAMES[$idx]}"
    status="${CHECK_STATUS[$idx]}"
    details="${CHECK_DETAILS[$idx]}"
    name="${name//|/\\|}"
    details="${details//|/\\|}"
    if [[ "${status}" == "PASS" ]]; then
      status="✅ PASS"
    else
      status="❌ FAIL"
    fi
    echo "| ${id} | ${name} | ${status} | ${details} |"
  done
  echo
  if (( FAIL_COUNT == 0 )); then
    echo "## Final Result"
    echo
    echo "✅ PASS (${PASS_COUNT}/${#CHECK_IDS[@]})"
  else
    echo "## Final Result"
    echo
    echo "❌ FAIL (${PASS_COUNT} passed, ${FAIL_COUNT} failed)"
  fi
} > "${REPORT_PATH}"

echo "Verification complete."
echo "Report: ${REPORT_PATH}"
echo "Checks: ${#CHECK_IDS[@]} | PASS: ${PASS_COUNT} | FAIL: ${FAIL_COUNT}"

if (( FAIL_COUNT > 0 )); then
  exit 1
fi
