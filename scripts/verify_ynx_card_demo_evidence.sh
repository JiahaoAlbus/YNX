#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${1:-$ROOT_DIR/output/ynx_card_demo_latest}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Demo evidence directory not found: $TARGET_DIR" >&2
  exit 1
fi

required_files=(
  "03_policy.json"
  "05_agent.json"
  "06_card.json"
  "08_authorize_approved.json"
  "09_settle.json"
  "10_reverse.json"
  "11_refund.json"
  "12_authorize_declined.json"
  "13_card_detail.json"
  "14_audit.json"
)

for file in "${required_files[@]}"; do
  [[ -f "$TARGET_DIR/$file" ]] || { echo "Missing required evidence file: $file" >&2; exit 1; }
done

run_id="$(sed -n 's/^- Run id: `\(.*\)`$/\1/p' "$TARGET_DIR/README.md" | head -n 1)"
verified_at_utc="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
checks_jsonl="$TARGET_DIR/.verification_checks.jsonl"
rm -f "$checks_jsonl"

record_check() {
  local id="$1"
  local status="$2"
  local detail="$3"
  jq -nc --arg id "$id" --arg status "$status" --arg detail "$detail" \
    '{id:$id,status:$status,detail:$detail}' >> "$checks_jsonl"
}

check_jq() {
  local id="$1"
  local expr="$2"
  local file="$3"
  local detail="$4"
  if jq -e "$expr" "$file" >/dev/null; then
    record_check "$id" "pass" "$detail"
  else
    record_check "$id" "fail" "$detail"
  fi
}

check_jq "approved_authorization" '.ok == true and .authorization.approved == true and .authorization.status == "authorized"' \
  "$TARGET_DIR/08_authorize_approved.json" \
  "approved authorization remains in authorized state before reconciliation"

check_jq "settlement_recorded" '.ok == true and .transaction.type == "settled" and .authorization.capture_total == 12 and .authorization.status == "partially_settled"' \
  "$TARGET_DIR/09_settle.json" \
  "settlement step records captured amount and partially settled status"

check_jq "reversal_recorded" '.ok == true and .transaction.type == "reversed" and .authorization.reversed_total == 8 and .authorization.status == "settled"' \
  "$TARGET_DIR/10_reverse.json" \
  "reversal step clears remaining authorization hold"

check_jq "refund_recorded" '.ok == true and .transaction.type == "refunded" and .authorization.refunded_total == 4 and .authorization.net_settled_total == 8 and .authorization.status == "partially_refunded"' \
  "$TARGET_DIR/11_refund.json" \
  "refund step reduces settled amount while preserving prior settlement trail"

check_jq "decline_recorded" '.ok == false and .authorization.approved == false' \
  "$TARGET_DIR/12_authorize_declined.json" \
  "out-of-policy authorization is rejected"

check_jq "card_detail_transactions" '([.transactions[].type] | sort) == ["refunded","reversed","settled"] and ([.authorizations[].status] | index("partially_refunded")) != null and ([.authorizations[].status] | index("declined")) != null' \
  "$TARGET_DIR/13_card_detail.json" \
  "card detail exposes reconciliation ledger and both approval/decline outcomes"

check_jq "audit_events_present" '([.items[].event] | index("card.authorized")) != null and ([.items[].event] | index("card.settled")) != null and ([.items[].event] | index("card.reversed")) != null and ([.items[].event] | index("card.refunded")) != null and ([.items[].event] | index("card.declined")) != null' \
  "$TARGET_DIR/14_audit.json" \
  "audit log preserves authorization and reconciliation lifecycle events"

checks_json="$(jq -s '.' "$checks_jsonl")"
pass_count="$(jq '[.[] | select(.status=="pass")] | length' <<<"$checks_json")"
fail_count="$(jq '[.[] | select(.status=="fail")] | length' <<<"$checks_json")"
overall_status="pass"
if [[ "$fail_count" != "0" ]]; then
  overall_status="fail"
fi

jq -n \
  --arg run_id "$run_id" \
  --arg verified_at_utc "$verified_at_utc" \
  --arg overall_status "$overall_status" \
  --argjson checks "$checks_json" \
  --argjson pass_count "$pass_count" \
  --argjson fail_count "$fail_count" \
  '{
    run_id: $run_id,
    verified_at_utc: $verified_at_utc,
    overall_status: $overall_status,
    pass_count: $pass_count,
    fail_count: $fail_count,
    checks: $checks
  }' > "$TARGET_DIR/15_verification.json"

cat > "$TARGET_DIR/VERIFICATION.md" <<EOF
# YNX Card Demo Verification

- Run id: \`${run_id}\`
- Verified: ${verified_at_utc}
- Overall status: ${overall_status}
- Passed checks: ${pass_count}
- Failed checks: ${fail_count}

## Check summary

EOF

jq -r '.checks[] | "- [" + (if .status == "pass" then "x" else " " end) + "] `" + .id + "` — " + .detail' \
  "$TARGET_DIR/15_verification.json" >> "$TARGET_DIR/VERIFICATION.md"

rm -f "$checks_jsonl"

if [[ "$overall_status" != "pass" ]]; then
  echo "YNX Card demo verification failed: $TARGET_DIR/15_verification.json" >&2
  exit 1
fi

echo "YNX Card demo verification passed: $TARGET_DIR/15_verification.json"
