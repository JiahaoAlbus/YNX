#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  v2_extreme_perf_bench.sh
  v2_extreme_perf_bench.sh --ai-url <url> --web4-url <url> [options]

Options:
  --ai-url <url>             default: https://ai.ynxweb4.com
  --web4-url <url>           default: https://web4.ynxweb4.com
  --read-connections <num>   default: 100
  --read-duration <sec>      default: 20
  --write-total <num>        default: 3000
  --write-concurrency <num>  default: 50

Outputs:
  - read-path benchmark (GET /health)
  - write-path benchmark (POST /ai/jobs with policy/session enforcement)
EOF
}

AI_URL="https://ai.ynxweb4.com"
WEB4_URL="https://web4.ynxweb4.com"
READ_CONNECTIONS="100"
READ_DURATION="20"
WRITE_TOTAL="3000"
WRITE_CONCURRENCY="50"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ai-url)
      AI_URL="${2:-}"; shift 2;;
    --web4-url)
      WEB4_URL="${2:-}"; shift 2;;
    --read-connections)
      READ_CONNECTIONS="${2:-}"; shift 2;;
    --read-duration)
      READ_DURATION="${2:-}"; shift 2;;
    --write-total)
      WRITE_TOTAL="${2:-}"; shift 2;;
    --write-concurrency)
      WRITE_CONCURRENCY="${2:-}"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

for bin in jq curl node npx; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Missing dependency: $bin" >&2
    exit 1
  fi
done

echo "==> Preflight"
curl -fsS --max-time 8 "${AI_URL}/ready" | jq -e '.ok == true' >/dev/null
curl -fsS --max-time 8 "${WEB4_URL}/ready" | jq -e '.ok == true' >/dev/null

echo "==> Read benchmark: ${AI_URL}/health"
READ_RESULT="$(npx --yes autocannon -j -c "${READ_CONNECTIONS}" -d "${READ_DURATION}" "${AI_URL}/health")"

echo "==> Setup policy/session for write benchmark"
POLICY_RESP="$(curl -fsS -X POST "${WEB4_URL}/web4/policies" \
  -H 'content-type: application/json' \
  -d '{"owner":"perf-owner","name":"perf-ai-job","allowed_actions":["ai.job.create"],"default_session_max_ops":1000000,"default_session_max_spend":0}')"
POLICY_ID="$(echo "${POLICY_RESP}" | jq -r '.policy.policy_id')"
OWNER_SECRET="$(echo "${POLICY_RESP}" | jq -r '.owner_secret')"

SESSION_RESP="$(curl -fsS -X POST "${WEB4_URL}/web4/policies/${POLICY_ID}/sessions" \
  -H "x-ynx-owner: ${OWNER_SECRET}" \
  -H 'content-type: application/json' \
  -d '{"max_ops":1000000,"max_spend":0,"capabilities":["ai.job.create"]}')"
SESSION_TOKEN="$(echo "${SESSION_RESP}" | jq -r '.token')"

if [[ -z "${POLICY_ID}" || "${POLICY_ID}" == "null" || -z "${SESSION_TOKEN}" || "${SESSION_TOKEN}" == "null" ]]; then
  echo "Failed to setup policy/session" >&2
  echo "${POLICY_RESP}" >&2
  echo "${SESSION_RESP}" >&2
  exit 1
fi

echo "==> Write benchmark: ${AI_URL}/ai/jobs"
export BENCH_AI_URL="${AI_URL}"
export BENCH_POLICY_ID="${POLICY_ID}"
export BENCH_SESSION_TOKEN="${SESSION_TOKEN}"
export BENCH_WRITE_TOTAL="${WRITE_TOTAL}"
export BENCH_WRITE_CONCURRENCY="${WRITE_CONCURRENCY}"
WRITE_RESULT="$(
node - <<'JS'
const aiUrl = process.env.BENCH_AI_URL;
const policyId = process.env.BENCH_POLICY_ID;
const sessionToken = process.env.BENCH_SESSION_TOKEN;
const total = Number(process.env.BENCH_WRITE_TOTAL || "3000");
const concurrency = Number(process.env.BENCH_WRITE_CONCURRENCY || "50");

let idx = 0;
let ok = 0;
let non2xx = 0;
let failed = 0;

function makePayload() {
  const id = `job_perf_${Date.now()}_${Math.random().toString(16).slice(2)}`;
  return JSON.stringify({
    job_id: id,
    creator: "perf-bench",
    policy_id: policyId,
  });
}

async function one() {
  try {
    const res = await fetch(`${aiUrl}/ai/jobs`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-ynx-session": sessionToken,
      },
      body: makePayload(),
    });
    if (res.ok) ok += 1;
    else non2xx += 1;
    await res.arrayBuffer();
  } catch {
    failed += 1;
  }
}

async function worker() {
  while (true) {
    const cur = idx;
    idx += 1;
    if (cur >= total) return;
    await one();
  }
}

(async () => {
  const t0 = process.hrtime.bigint();
  await Promise.all(Array.from({ length: concurrency }, () => worker()));
  const sec = Number(process.hrtime.bigint() - t0) / 1e9;
  console.log(JSON.stringify({
    total,
    concurrency,
    seconds: Number(sec.toFixed(3)),
    rps: Number((total / sec).toFixed(2)),
    ok,
    non2xx,
    failed,
  }));
})();
JS
)"

echo
echo "=== READ SUMMARY ==="
echo "${READ_RESULT}" | jq -r '{
  requests_avg_rps:.requests.average,
  requests_total:.requests.total,
  latency_avg_ms:.latency.average,
  errors:.errors,
  timeouts:.timeouts,
  non2xx:.non2xx
}'

echo
echo "=== WRITE SUMMARY ==="
echo "${WRITE_RESULT}" | jq -r '.'

echo
echo "policy_id=${POLICY_ID}"
echo "done"
