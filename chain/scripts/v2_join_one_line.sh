#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Shared terminal UI: Klein blue + white, consistent progress, plan view.
source "$SCRIPT_DIR/lib/ynx_ui.sh"
ynx_ui_init

usage() {
  cat <<'USAGE'
Usage:
  v2_join_one_line.sh [options]

Fresh-machine one-liner bootstrap for YNX v2.
It clones/updates the repo, then runs scripts/v2_join_auto.sh.

Options:
  --role <full-node|validator|public-rpc>  default: full-node
  --home <path>                            default: ~/.ynx-v2-join
  --rpc <url>                              default: https://rpc.ynxweb4.com
  --chain-id <id>                          default: ynx_9102-1
  --sync-timeout <seconds>                 default: 1800
  --peer-wait <seconds>                    default: 600
  --rpc-wait <seconds>                     default: 300
  --port-offset <n>                        default: auto (0 or 100 if default port busy)
  --statesync                              enable statesync (default: off)
  --install-deps                           auto install missing deps (default: on)
  --no-install-deps                        disable auto install missing deps
  --go-version <version>                   default: 1.25.7
  --repo-url <git_url>                     default: https://github.com/JiahaoAlbus/YNX.git
  --repo-branch <branch>                   default: main
  --workdir <path>                         default: ~/.ynx-bootstrap
  --plan-only                              print resolved flow and exit
  --interactive                            keep interactive role selection
  -h, --help
USAGE
}

ROLE="full-node"
HOME_DIR="${HOME}/.ynx-v2-join"
RPC_URL="https://rpc.ynxweb4.com"
CHAIN_ID="ynx_9102-1"
SYNC_TIMEOUT=1800
PEER_WAIT=600
RPC_WAIT=300
PORT_OFFSET=""
ENABLE_STATESYNC=0
INSTALL_DEPS=1
GO_VERSION="1.25.7"
REPO_URL="https://github.com/JiahaoAlbus/YNX.git"
REPO_BRANCH="main"
WORKDIR="${HOME}/.ynx-bootstrap"
INTERACTIVE=0
PLAN_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --home) HOME_DIR="${2:-}"; shift 2 ;;
    --rpc) RPC_URL="${2:-}"; shift 2 ;;
    --chain-id) CHAIN_ID="${2:-}"; shift 2 ;;
    --sync-timeout) SYNC_TIMEOUT="${2:-}"; shift 2 ;;
    --peer-wait) PEER_WAIT="${2:-}"; shift 2 ;;
    --rpc-wait) RPC_WAIT="${2:-}"; shift 2 ;;
    --port-offset) PORT_OFFSET="${2:-}"; shift 2 ;;
    --statesync) ENABLE_STATESYNC=1; shift ;;
    --install-deps) INSTALL_DEPS=1; shift ;;
    --no-install-deps) INSTALL_DEPS=0; shift ;;
    --go-version) GO_VERSION="${2:-}"; shift 2 ;;
    --repo-url) REPO_URL="${2:-}"; shift 2 ;;
    --repo-branch) REPO_BRANCH="${2:-}"; shift 2 ;;
    --workdir) WORKDIR="${2:-}"; shift 2 ;;
    --plan-only) PLAN_ONLY=1; shift ;;
    --interactive) INTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

for n in "$SYNC_TIMEOUT" "$PEER_WAIT" "$RPC_WAIT"; do
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "Timeout values must be integers" >&2
    exit 1
  fi
done
if [[ -n "$PORT_OFFSET" ]] && ! [[ "$PORT_OFFSET" =~ ^[0-9]+$ ]]; then
  echo "--port-offset must be integer >= 0" >&2
  exit 1
fi

step=0
total=6
print_step() {
  step=$((step + 1))
  ynx_ui_step "$step" "$total" "$*"
}

OS_RAW="$(uname -s 2>/dev/null || echo unknown)"
OS_NAME="$(echo "$OS_RAW" | tr '[:upper:]' '[:lower:]')"

ynx_ui_banner "Fresh-machine bootstrap" "This entrypoint prepares the machine, fetches the repo, then hands off to the join flow."
ynx_ui_plan "One-line bootstrap order" \
  "Check base dependencies and shell environment" \
  "Prepare or refresh the working copy of the YNX repo" \
  "Resolve the downstream join entry script" \
  "Install or expose the Go toolchain only if needed" \
  "Run the chain join + verify flow" \
  "Print the final result or diagnostics"
ynx_ui_kv "role" "$ROLE"
ynx_ui_kv "home" "$HOME_DIR"
ynx_ui_kv "rpc" "$RPC_URL"
ynx_ui_kv "chain_id" "$CHAIN_ID"
ynx_ui_kv "repo_url" "$REPO_URL"
ynx_ui_kv "repo_branch" "$REPO_BRANCH"
ynx_ui_kv "workdir" "$WORKDIR"
ynx_ui_kv "statesync" "$ENABLE_STATESYNC"
ynx_ui_kv "plan_only" "$PLAN_ONLY"
echo

if [[ "$PLAN_ONLY" -eq 1 ]]; then
  ynx_ui_note "Plan-only mode: no files changed and no network/bootstrap action executed."
  exit 0
fi

if [[ "$OS_NAME" == *mingw* || "$OS_NAME" == *msys* || "$OS_NAME" == *cygwin* ]]; then
  echo "Windows native shell detected." >&2
  echo "Run this in PowerShell (it starts WSL2 automatically):" >&2
  echo "wsl -d Ubuntu -- bash -lc 'curl -fsSL https://raw.githubusercontent.com/JiahaoAlbus/YNX/main/chain/scripts/v2_join_one_line.sh | bash -s -- --role full-node'" >&2
  exit 1
fi

run_pkg_install() {
  local packages="$1"
  if [[ -z "$packages" ]]; then
    return 0
  fi
  local prefix=""
  if [[ "$(id -u)" -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    prefix="sudo"
  fi

  if command -v apt-get >/dev/null 2>&1; then
    ${prefix} apt-get update -y && ${prefix} apt-get install -y $packages
  elif command -v dnf >/dev/null 2>&1; then
    ${prefix} dnf install -y $packages
  elif command -v yum >/dev/null 2>&1; then
    ${prefix} yum install -y $packages
  elif command -v pacman >/dev/null 2>&1; then
    ${prefix} pacman -Sy --noconfirm $packages
  elif command -v zypper >/dev/null 2>&1; then
    ${prefix} zypper --non-interactive install $packages
  elif command -v apk >/dev/null 2>&1; then
    ${prefix} apk add --no-cache $packages
  elif command -v brew >/dev/null 2>&1; then
    brew install $packages
  else
    return 1
  fi
}

install_missing_base_deps() {
  local missing=()
  local dep
  for dep in git curl jq bash; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing+=("$dep")
    fi
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    return 0
  fi
  if [[ "$INSTALL_DEPS" -ne 1 ]]; then
    echo "Missing dependencies: ${missing[*]}" >&2
    echo "Re-run with --install-deps or install manually." >&2
    exit 1
  fi

  local pkg_list=""
  if [[ "$OS_NAME" == *darwin* ]]; then
    pkg_list="git jq curl"
  else
    pkg_list="git curl jq bash ca-certificates"
  fi
  run_pkg_install "$pkg_list" || {
    echo "Auto install failed. Please install manually: ${missing[*]}" >&2
    exit 1
  }
}

install_go_toolchain() {
  if command -v go >/dev/null 2>&1; then
    return 0
  fi
  local arch_raw arch os
  arch_raw="$(uname -m)"
  case "$arch_raw" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "Unsupported architecture for auto Go install: $arch_raw" >&2
      return 1
      ;;
  esac
  case "$OS_NAME" in
    *darwin*) os="darwin" ;;
    *linux*) os="linux" ;;
    *)
      echo "Unsupported OS for auto Go install: $OS_RAW" >&2
      return 1
      ;;
  esac

  local toolchain_dir="${WORKDIR}/.toolchain"
  local go_dir="${toolchain_dir}/go"
  local tarball="${toolchain_dir}/go${GO_VERSION}.${os}-${arch}.tar.gz"
  mkdir -p "$toolchain_dir"

  if [[ ! -x "$go_dir/bin/go" ]]; then
    local url="https://go.dev/dl/go${GO_VERSION}.${os}-${arch}.tar.gz"
    echo "Installing Go ${GO_VERSION} (${os}/${arch})..."
    curl -fsSL "$url" -o "$tarball"
    rm -rf "$go_dir"
    tar -xzf "$tarball" -C "$toolchain_dir"
  fi
  export PATH="$go_dir/bin:$PATH"
  command -v go >/dev/null 2>&1 || return 1
}

print_step "check prerequisites"
install_missing_base_deps

print_step "prepare workspace"
mkdir -p "$WORKDIR"
REPO_DIR="$WORKDIR/YNX"

# Local directory source keeps working-tree changes (useful for dev/staging verification).
if [[ -d "$REPO_URL" ]]; then
  rm -rf "$REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "${REPO_URL%/}/" "${REPO_DIR}/"
  else
    cp -a "$REPO_URL" "$REPO_DIR"
  fi
else
  if [[ -d "$REPO_DIR/.git" ]]; then
    git -C "$REPO_DIR" fetch --depth=1 origin "$REPO_BRANCH"
    git -C "$REPO_DIR" reset --hard "origin/$REPO_BRANCH"
  else
    git clone --depth=1 --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
  fi
fi

print_step "prepare join script"
JOIN_SCRIPT="$REPO_DIR/chain/scripts/v2_join_auto.sh"
if [[ ! -x "$JOIN_SCRIPT" ]]; then
  chmod +x "$JOIN_SCRIPT"
fi

print_step "prepare toolchain"
if [[ ! -x "$REPO_DIR/chain/ynxd" ]] && ! command -v ynxd >/dev/null 2>&1 && ! command -v go >/dev/null 2>&1; then
  if [[ "$INSTALL_DEPS" -ne 1 ]]; then
    echo "Missing go and no ynxd binary found. Re-run with --install-deps." >&2
    exit 1
  fi
  install_go_toolchain || {
    echo "Failed to install Go automatically. Install Go ${GO_VERSION}+ manually and retry." >&2
    exit 1
  }
fi

print_step "run join flow"
CMD=(
  "$JOIN_SCRIPT"
  --home "$HOME_DIR"
  --rpc "$RPC_URL"
  --chain-id "$CHAIN_ID"
  --sync-timeout "$SYNC_TIMEOUT"
  --peer-wait "$PEER_WAIT"
  --rpc-wait "$RPC_WAIT"
  --no-reset
)
if [[ "$INTERACTIVE" -eq 0 ]]; then
  CMD+=(--yes --role "$ROLE")
fi
if [[ "$ENABLE_STATESYNC" -eq 1 ]]; then
  CMD+=(--statesync)
fi
if [[ -n "$PORT_OFFSET" ]]; then
  CMD+=(--port-offset "$PORT_OFFSET")
fi
if [[ "$PLAN_ONLY" -eq 1 ]]; then
  CMD+=(--plan-only)
fi

"${CMD[@]}"

print_step "complete"
ynx_ui_note "YNX join flow finished."
