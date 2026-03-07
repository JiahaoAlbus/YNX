#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  build_linux_ynxd.sh [output_path]

Build a Linux amd64 `ynxd` binary from the current local source tree.

Default output:
  chain/.artifacts/ynxd-linux-amd64
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_PATH="${1:-$ROOT_DIR/.artifacts/ynxd-linux-amd64}"

mkdir -p "$(dirname "$OUT_PATH")"

(
  cd "$ROOT_DIR"
  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -buildvcs=false -o "$OUT_PATH" ./cmd/ynxd
)

chmod +x "$OUT_PATH"
echo "$OUT_PATH"
