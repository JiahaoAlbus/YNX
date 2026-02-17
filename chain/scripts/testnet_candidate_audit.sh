#!/usr/bin/env bash

set -euo pipefail

INPUT=""
OUT=""
TIMEOUT="3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT="${2:-}"
      shift 2
      ;;
    --out)
      OUT="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:-3}"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--input FILE] [--out FILE] [--timeout SEC]

Batch-audit validator candidate P2P endpoints.

Input format:
  - one endpoint per line: node_id@host:26656
  - or CSV lines containing a node_id@host:port token
  - blank lines and lines starting with # are ignored

Examples:
  $0 --input candidates.txt
  $0 --input candidates.csv --out report.md --timeout 5
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -n "$INPUT" && ! -f "$INPUT" ]]; then
  echo "Input file not found: $INPUT" >&2
  exit 1
fi

if [[ -z "$OUT" ]]; then
  TS="$(date +%Y%m%d-%H%M%S)"
  OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.release/candidate-audit-${TS}.md"
fi

mkdir -p "$(dirname "$OUT")"

if [[ -n "$INPUT" ]]; then
  SRC="$(cat "$INPUT")"
else
  SRC="$(cat)"
fi

extract_endpoint() {
  local line="$1"
  echo "$line" | grep -Eo '[0-9A-Fa-f]{40}@[A-Za-z0-9._-]+:[0-9]{2,5}' | head -n 1 || true
}

tcp_check() {
  local host="$1"
  local port="$2"
  nc -z -w "$TIMEOUT" "$host" "$port" >/dev/null 2>&1
}

rpc_node_id() {
  local host="$1"
  local rpc_port="${2:-26657}"
  curl -sS --max-time "$TIMEOUT" "http://${host}:${rpc_port}/status" 2>/dev/null \
    | node -e "const fs=require('fs');const d=fs.readFileSync(0,'utf8');if(!d){process.exit(1)};const j=JSON.parse(d);process.stdout.write((j.result?.node_info?.id)||'')" \
    2>/dev/null || true
}

{
  echo "# YNX Validator Candidate Audit Report"
  echo
  echo "- Generated at: \`$(date -u +"%Y-%m-%dT%H:%M:%SZ")\`"
  echo "- Timeout per check: \`${TIMEOUT}s\`"
  echo
  echo "| Candidate | P2P TCP | RPC NodeID | NodeID Match | Status |"
  echo "|---|---|---|---|---|"
} > "$OUT"

total=0
pass=0
failed=0

while IFS= read -r raw; do
  line="$(echo "$raw" | xargs || true)"
  [[ -z "$line" ]] && continue
  [[ "${line:0:1}" == "#" ]] && continue

  endpoint="$(extract_endpoint "$line")"
  [[ -z "$endpoint" ]] && continue

  total=$((total + 1))
  expected_id="${endpoint%@*}"
  host_port="${endpoint#*@}"
  host="${host_port%:*}"
  port="${host_port##*:}"

  if tcp_check "$host" "$port"; then
    p2p="open"
  else
    p2p="closed"
  fi

  actual_id="$(rpc_node_id "$host" "26657")"
  if [[ -n "$actual_id" ]]; then
    rpc="ok"
  else
    rpc="unreachable"
  fi

  if [[ -n "$actual_id" && "$actual_id" == "$expected_id" ]]; then
    match="yes"
  elif [[ -n "$actual_id" ]]; then
    match="no"
  else
    match="unknown"
  fi

  if [[ "$p2p" == "open" && "$match" == "yes" ]]; then
    status="approved"
    pass=$((pass + 1))
  else
    status="review"
    failed=$((failed + 1))
  fi

  echo "| \`$endpoint\` | $p2p | $rpc | $match | $status |" >> "$OUT"
done <<< "$SRC"

{
  echo
  echo "## Summary"
  echo
  echo "- Total: \`${total}\`"
  echo "- Approved: \`${pass}\`"
  echo "- Needs review: \`${failed}\`"
} >> "$OUT"

echo "Audit report written to: $OUT"
