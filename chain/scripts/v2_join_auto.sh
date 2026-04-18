#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/ynx_ui.sh"
ynx_ui_init

usage() {
  cat <<'USAGE'
Usage:
  v2_join_auto.sh [options]

User-friendly one-command entry for YNX v2 join + verify.
It auto-detects OS, discovers chain path, and runs v2_join_and_verify.sh.

Options:
  --role <full-node|validator|public-rpc>  default: interactive prompt
  --home <path>                            default: ~/.ynx-v2-join
  --rpc <url>                              default: https://rpc.ynxweb4.com
  --chain-id <id>                          default: ynx_9102-1
  --persistent-peers <list>                optional override
  --statesync                              enable state sync (default: off)
  --no-reset                               keep existing home
  --port-offset <n>                        default: auto (0 or 100 if default port busy)
  --sync-timeout <seconds>                 default: 1800
  --peer-wait <seconds>                    default: 600
  --rpc-wait <seconds>                     default: 300
  --plan-only                              print resolved flow and exit
  --yes                                    non-interactive (defaults role=full-node)
  -h, --help                               show help
USAGE
}

ROLE=""
HOME_DIR="${HOME}/.ynx-v2-join"
RPC_URL="https://rpc.ynxweb4.com"
CHAIN_ID="ynx_9102-1"
PERSISTENT_PEERS=""
RESET=1
ENABLE_STATESYNC=0
PORT_OFFSET=""
SYNC_TIMEOUT=1800
PEER_WAIT=600
RPC_WAIT=300
YES=0
PLAN_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --home) HOME_DIR="${2:-}"; shift 2 ;;
    --rpc) RPC_URL="${2:-}"; shift 2 ;;
    --chain-id) CHAIN_ID="${2:-}"; shift 2 ;;
    --persistent-peers) PERSISTENT_PEERS="${2:-}"; shift 2 ;;
    --statesync) ENABLE_STATESYNC=1; shift ;;
    --no-reset) RESET=0; shift ;;
    --port-offset) PORT_OFFSET="${2:-}"; shift 2 ;;
    --sync-timeout) SYNC_TIMEOUT="${2:-}"; shift 2 ;;
    --peer-wait) PEER_WAIT="${2:-}"; shift 2 ;;
    --rpc-wait) RPC_WAIT="${2:-}"; shift 2 ;;
    --plan-only) PLAN_ONLY=1; shift ;;
    --yes) YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

for n in "$SYNC_TIMEOUT" "$PEER_WAIT" "$RPC_WAIT"; do
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "Timeout values must be integer" >&2
    exit 1
  fi
done
if [[ -n "$PORT_OFFSET" ]] && ! [[ "$PORT_OFFSET" =~ ^[0-9]+$ ]]; then
  echo "--port-offset must be integer >= 0" >&2
  exit 1
fi

OS_RAW="$(uname -s 2>/dev/null || echo unknown)"
OS_NAME="$(echo "$OS_RAW" | tr '[:upper:]' '[:lower:]')"

STEP=0
TOTAL=6
step() {
  STEP=$((STEP + 1))
  if [[ "${YNX_UI_GLOBAL_MODE:-0}" -eq 1 ]]; then
    local pct=0
    local detail=""
    case "$STEP" in
      1) pct=34; detail="inspect uname, shell, and supported runtime mode" ;;
      2) pct=38; detail="resolve the chain workspace and entry scripts on this machine" ;;
      3) pct=40; detail="resolve ynxd or prepare a build from source" ;;
      4) pct=68; detail="delegate to the chain join and verification pipeline" ;;
      5) pct=98; detail="collect final local node result and operator output" ;;
      6) pct=100; detail="repo-local dispatcher completed" ;;
      *) pct=100 ;;
    esac
    ynx_ui_progress_reset_metrics
    ynx_ui_progress "$pct" "$*" "$detail"
  else
    ynx_ui_step "$STEP" "$TOTAL" "$*"
  fi
}

build_ynxd() {
  local output_bin="$1"
  shift || true
  local -a proxies=(
    "https://proxy.golang.org,direct"
    "https://goproxy.io,direct"
    "https://goproxy.cn,direct"
  )
  local proxy
  local last_rc=1
  local module_total package_total module_done package_done pct
  local mod_log build_log cmd_pid build_last_line

  module_total="$(go list -m -mod=mod all 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
  package_total="$(go list -deps ./cmd/ynxd 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
  if ! [[ "$module_total" =~ ^[0-9]+$ ]]; then
    module_total=0
  fi
  if ! [[ "$package_total" =~ ^[0-9]+$ ]]; then
    package_total=0
  fi

  mod_log="$(mktemp "${TMPDIR:-/tmp}/ynx-go-mod.XXXXXX.log")"
  build_log="$(mktemp "${TMPDIR:-/tmp}/ynx-go-build.XXXXXX.log")"
  trap 'rm -f "$mod_log" "$build_log"' RETURN

  for proxy in "${proxies[@]}"; do
    ynx_ui_stdout "Building ynxd with GOPROXY=$proxy ..."
    module_done=0
    package_done=0
    ynx_ui_progress_set_meta "n/a" "n/a"
    ynx_ui_progress 40 "prepare binary" "go mod download | resolve module graph via $proxy"

    : >"$mod_log"
    env \
      GOPROXY="${GOPROXY:-$proxy}" \
      GOSUMDB="${GOSUMDB:-sum.golang.org}" \
      GIT_TERMINAL_PROMPT=0 \
      CGO_ENABLED=0 \
      go mod download -json all >"$mod_log" 2>&1 &
    cmd_pid=$!
    while kill -0 "$cmd_pid" >/dev/null 2>&1; do
      module_done="$(grep -c '"Path":' "$mod_log" 2>/dev/null || true)"
      if ! [[ "$module_done" =~ ^[0-9]+$ ]]; then
        module_done=0
      fi
      if (( module_total > 0 )); then
        pct=$((40 + (module_done * 12 / module_total)))
        if (( pct > 52 )); then
          pct=52
        fi
        ynx_ui_progress_metric "$pct" "prepare binary" "go mod download | modules ${module_done}/${module_total} via $proxy" "mod-download" "$module_done" "$module_total" "mod"
      fi
      sleep 0.3
    done
    if wait "$cmd_pid"; then
      module_done="$(grep -c '"Path":' "$mod_log" 2>/dev/null || true)"
      if ! [[ "$module_done" =~ ^[0-9]+$ ]]; then
        module_done=0
      fi
      if (( module_total > 0 )); then
        ynx_ui_progress_metric 52 "prepare binary" "go mod download | modules ${module_done}/${module_total} via $proxy" "mod-download" "$module_done" "$module_total" "mod"
      fi
      if (( package_total == 0 )); then
        package_total="$(env GOPROXY="${GOPROXY:-$proxy}" GOSUMDB="${GOSUMDB:-sum.golang.org}" GIT_TERMINAL_PROMPT=0 CGO_ENABLED=0 go list -deps ./cmd/ynxd 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
        if ! [[ "$package_total" =~ ^[0-9]+$ ]]; then
          package_total=0
        fi
      fi
      last_rc=0
    else
      last_rc=$?
    fi
    if (( last_rc != 0 )); then
      ynx_ui_stderr "Build attempt failed with GOPROXY=$proxy during module download"
      continue
    fi

    : >"$build_log"
    ynx_ui_progress_set_meta "n/a" "n/a"
    ynx_ui_progress 52 "prepare binary" "go build ./cmd/ynxd | compile packages via $proxy"
    env \
      GOPROXY="${GOPROXY:-$proxy}" \
      GOSUMDB="${GOSUMDB:-sum.golang.org}" \
      GIT_TERMINAL_PROMPT=0 \
      CGO_ENABLED=0 \
      go build -v -buildvcs=false -o "$output_bin" ./cmd/ynxd >"$build_log" 2>&1 &
    cmd_pid=$!
    while kill -0 "$cmd_pid" >/dev/null 2>&1; do
      package_done="$(grep -vc '^go: downloading' "$build_log" 2>/dev/null || true)"
      build_last_line="$(tail -n 1 "$build_log" 2>/dev/null | sed 's/[[:space:]]*$//' || true)"
      if ! [[ "$package_done" =~ ^[0-9]+$ ]]; then
        package_done=0
      fi
      if (( package_done < 0 )); then
        package_done=0
      fi
      if (( package_total > 0 )); then
        pct=$((52 + (package_done * 16 / package_total)))
        if (( pct > 68 )); then
          pct=68
        fi
        ynx_ui_progress_metric "$pct" "prepare binary" "go build ./cmd/ynxd | packages ${package_done}/${package_total} | ${build_last_line:-waiting for compiler output}" "pkg-build" "$package_done" "$package_total" "pkg"
      else
        ynx_ui_progress 60 "prepare binary" "go build ./cmd/ynxd | ${build_last_line:-waiting for compiler output}"
      fi
      sleep 0.3
    done
    if wait "$cmd_pid"; then
      package_done="$(grep -vc '^go: downloading' "$build_log" 2>/dev/null || true)"
      if ! [[ "$package_done" =~ ^[0-9]+$ ]]; then
        package_done=0
      fi
      if (( package_total > 0 )); then
        ynx_ui_progress_metric 68 "prepare binary" "go build ./cmd/ynxd | packages ${package_done}/${package_total} | ${build_last_line:-build complete}" "pkg-build" "$package_done" "$package_total" "pkg"
      else
        ynx_ui_progress 68 "prepare binary" "go build ./cmd/ynxd | build complete"
      fi
      last_rc=0
    else
      last_rc=$?
    fi
    if (( last_rc == 0 )); then
      return 0
    fi
    ynx_ui_stderr "Build attempt failed with GOPROXY=$proxy"
  done

  return "$last_rc"
}

if [[ "${YNX_UI_SUPPRESS_HEADER:-0}" -ne 1 ]]; then
  ynx_ui_banner "Repo-local join dispatcher" "This layer detects the platform, resolves the chain workspace, finds ynxd, then invokes join + verify."
  ynx_ui_plan "Repo-local dispatcher order" \
    "Detect operating system and decide supported mode" \
    "Resolve the node role, interactive or non-interactive" \
    "Locate the YNX chain workspace in the current machine" \
    "Build or reuse the ynxd binary" \
    "Launch join + verify with resolved parameters" \
    "Print quick next actions for the chosen role"
  ynx_ui_kv "home" "$HOME_DIR"
  ynx_ui_kv "rpc" "$RPC_URL"
  ynx_ui_kv "chain_id" "$CHAIN_ID"
  ynx_ui_kv "port_offset" "${PORT_OFFSET:-auto}"
  ynx_ui_kv "plan_only" "$PLAN_ONLY"
  echo
fi

choose_role_interactive() {
  ynx_ui_flush_progress
  echo
  echo "Select node role:"
  echo "  1) full-node (recommended for normal users)"
  echo "  2) validator"
  echo "  3) public-rpc"
  read -r -p "Enter 1/2/3 [1]: " choice
  case "${choice:-1}" in
    1) ROLE="full-node" ;;
    2) ROLE="validator" ;;
    3) ROLE="public-rpc" ;;
    *) echo "Invalid selection" >&2; exit 1 ;;
  esac
}

step "detect system"
ynx_ui_stdout "OS: $OS_RAW"
if [[ "$OS_NAME" == *mingw* || "$OS_NAME" == *msys* || "$OS_NAME" == *cygwin* ]]; then
  echo "Windows native is not recommended for validator. Use WSL2 and run this script inside Linux shell." >&2
  exit 1
fi

if [[ -z "$ROLE" ]]; then
  if [[ "$YES" -eq 1 ]]; then
    ROLE="full-node"
  else
    choose_role_interactive
  fi
fi

case "$ROLE" in
  full-node|validator|public-rpc) ;;
  *) echo "Invalid role: $ROLE" >&2; exit 1 ;;
esac

ynx_ui_kv "resolved_role" "$ROLE"
if [[ "$PLAN_ONLY" -eq 1 ]]; then
  ynx_ui_note "Plan-only mode: role resolution ran, but no workspace mutation or network action will be executed."
fi

if [[ "$OS_NAME" == *darwin* && "$ROLE" != "full-node" ]]; then
  ynx_ui_stderr "WARNING: validator/public-rpc is strongly recommended on Linux server."
fi

step "locate chain workspace"
CHAIN_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${YNX_CHAIN_DIR:-}" && -f "${YNX_CHAIN_DIR}/cmd/ynxd/main.go" ]]; then
  CHAIN_DIR="${YNX_CHAIN_DIR}"
elif [[ -f "${SCRIPT_DIR}/../cmd/ynxd/main.go" && -f "${SCRIPT_DIR}/v2_join_and_verify.sh" ]]; then
  CHAIN_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
elif [[ -f "$(pwd)/cmd/ynxd/main.go" && -f "$(pwd)/scripts/v2_join_and_verify.sh" ]]; then
  CHAIN_DIR="$(pwd)"
elif [[ -f "$(pwd)/chain/cmd/ynxd/main.go" && -f "$(pwd)/chain/scripts/v2_join_and_verify.sh" ]]; then
  CHAIN_DIR="$(pwd)/chain"
elif [[ -f "$HOME/YNX/chain/cmd/ynxd/main.go" && -f "$HOME/YNX/chain/scripts/v2_join_and_verify.sh" ]]; then
  CHAIN_DIR="$HOME/YNX/chain"
fi

if [[ -z "$CHAIN_DIR" ]]; then
  echo "Cannot find YNX chain workspace. Run from YNX repo root or chain dir." >&2
  exit 1
fi
ynx_ui_stdout "CHAIN_DIR=$CHAIN_DIR"
if [[ "${YNX_UI_SUPPRESS_HEADER:-0}" -ne 1 ]]; then
  ynx_ui_kv "chain_dir" "$CHAIN_DIR"
fi

step "prepare binary"
cd "$CHAIN_DIR"
NODE_BIN=""
if [[ -x "$CHAIN_DIR/ynxd" ]]; then
  NODE_BIN="$CHAIN_DIR/ynxd"
elif command -v ynxd >/dev/null 2>&1; then
  NODE_BIN="$(command -v ynxd)"
  else
    if ! command -v go >/dev/null 2>&1; then
      echo "go is required to build ynxd when no binary is available." >&2
      exit 1
    fi
    ynx_ui_stdout "Building ynxd..."
    build_ynxd "$CHAIN_DIR/ynxd" || {
      echo "Failed to build ynxd after retrying multiple Go proxies." >&2
      exit 1
    }
    NODE_BIN="$CHAIN_DIR/ynxd"
  fi

ynx_ui_stdout "NODE_BIN=$NODE_BIN"
if [[ "${YNX_UI_SUPPRESS_HEADER:-0}" -ne 1 ]]; then
  ynx_ui_kv "node_bin" "$NODE_BIN"
fi

if [[ "$PLAN_ONLY" -eq 1 ]]; then
  ynx_ui_note "Plan-only mode: chain workspace and binary resolution succeeded."
  exit 0
fi

step "run join + verify"
CMD=(
  "$CHAIN_DIR/scripts/v2_join_and_verify.sh"
  --role "$ROLE"
  --home "$HOME_DIR"
  --rpc "$RPC_URL"
  --chain-id "$CHAIN_ID"
  --sync-timeout "$SYNC_TIMEOUT"
  --peer-wait "$PEER_WAIT"
  --rpc-wait "$RPC_WAIT"
)
if [[ -n "$PERSISTENT_PEERS" ]]; then
  CMD+=(--persistent-peers "$PERSISTENT_PEERS")
fi
if [[ -n "$PORT_OFFSET" ]]; then
  CMD+=(--port-offset "$PORT_OFFSET")
fi
if [[ "$ENABLE_STATESYNC" -eq 1 ]]; then
  CMD+=(--statesync)
fi
if [[ "$RESET" -eq 1 ]]; then
  CMD+=(--reset)
fi
if [[ "$PLAN_ONLY" -eq 1 ]]; then
  CMD+=(--plan-only)
fi

YNX_BIN="$NODE_BIN" \
YNX_UI_GLOBAL_MODE="${YNX_UI_GLOBAL_MODE:-0}" \
YNX_UI_SUPPRESS_HEADER=1 \
"${CMD[@]}"

step "done"
ynx_ui_note "Join + verify completed."

step "quick next actions"
if [[ "$ROLE" == "full-node" ]]; then
  ynx_ui_stdout "You joined as full-node."
else
  ynx_ui_stdout "Role=$ROLE joined. For validator self-delegation, run create-validator flow after funding."
fi
