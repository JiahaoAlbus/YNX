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

print_progress() {
  local pct="$1"
  local stage="${2:-}"
  local detail="${3:-}"
  ynx_ui_progress_reset_metrics
  ynx_ui_progress "$pct" "$stage" "$detail"
}

workspace_progress_from_git_line() {
  local line="$1"
  local pct=""
  if [[ "$line" =~ Counting\ objects:[[:space:]]+([0-9]{1,3})% ]]; then
    pct=$((12 + BASH_REMATCH[1] * 1 / 100))
  elif [[ "$line" =~ Compressing\ objects:[[:space:]]+([0-9]{1,3})% ]]; then
    pct=$((13 + BASH_REMATCH[1] * 1 / 100))
  elif [[ "$line" =~ Receiving\ objects:[[:space:]]+([0-9]{1,3})% ]]; then
    pct=$((14 + BASH_REMATCH[1] * 3 / 100))
  elif [[ "$line" =~ Resolving\ deltas:[[:space:]]+([0-9]{1,3})% ]]; then
    pct=$((17 + BASH_REMATCH[1] * 1 / 100))
  fi
  if [[ -n "$pct" ]]; then
    printf '%s\n' "$pct"
  fi
}

file_size_bytes() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo 0
    return 0
  fi
  if stat -f %z "$path" >/dev/null 2>&1; then
    stat -f %z "$path"
  else
    stat -c %s "$path"
  fi
}

github_archive_url_from_repo() {
  local repo_url="$1"
  local repo_branch="$2"
  local owner repo
  if [[ "$repo_url" =~ ^https://github\.com/([^/]+)/([^/]+)(\.git)?/?$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]%.git}"
    printf 'https://codeload.github.com/%s/%s/tar.gz/refs/heads/%s\n' "$owner" "$repo" "$repo_branch"
    return 0
  fi
  return 1
}

download_file_with_progress() {
  local url="$1"
  local dest="$2"
  local stage="${3:-download source archive}"
  local start_pct="${4:-12}"
  local end_pct="${5:-17}"
  local total_bytes current_bytes span pct stage_text current_mb total_mb
  span=$((end_pct - start_pct))

  total_bytes="$(
    curl -fsSLI "$url" 2>/dev/null \
      | tr -d '\r' \
      | awk 'tolower($1)=="content-length:"{print $2}' \
      | tail -n1
  )"
  if ! [[ "$total_bytes" =~ ^[0-9]+$ ]] || (( total_bytes <= 0 )); then
    total_bytes="$(curl -fsSL "$url" -o /dev/null -w '%{size_download}' 2>/dev/null || true)"
  fi

  curl -fsSL "$url" -o "$dest" &
  local curl_pid=$!

  if [[ "$total_bytes" =~ ^[0-9]+$ ]] && (( total_bytes > 0 )); then
    while kill -0 "$curl_pid" >/dev/null 2>&1; do
      current_bytes="$(file_size_bytes "$dest")"
      pct=$((start_pct + (current_bytes * span / total_bytes)))
      if (( pct > end_pct )); then
        pct="$end_pct"
      fi
      current_mb="$(awk -v cur="$current_bytes" 'BEGIN { printf "%.1f", cur/1048576 }')"
      total_mb="$(awk -v total="$total_bytes" 'BEGIN { printf "%.1f", total/1048576 }')"
      stage_text="$stage ($(awk -v cur="$current_bytes" -v total="$total_bytes" 'BEGIN { printf "%.1f/%.1f MB", cur/1048576, total/1048576 }'))"
      ynx_ui_progress_metric "$pct" "$stage" "$stage_text" "archive-download" "$current_mb" "$total_mb" "MB"
      sleep 0.2
    done
  fi

  wait "$curl_pid"
  if [[ "$total_bytes" =~ ^[0-9]+$ ]] && (( total_bytes > 0 )); then
    total_mb="$(awk -v total="$total_bytes" 'BEGIN { printf "%.1f", total/1048576 }')"
    stage_text="$stage ($(awk -v total="$total_bytes" 'BEGIN { printf "%.1f/%.1f MB", total/1048576, total/1048576 }'))"
    ynx_ui_progress_metric "$end_pct" "$stage" "$stage_text" "archive-download" "$total_mb" "$total_mb" "MB"
  else
    print_progress "$end_pct" "$stage" "source archive downloaded"
  fi
}

prepare_workspace_from_github_archive() {
  local archive_url archive_path top_dir extracted_dir
  archive_url="$(github_archive_url_from_repo "$REPO_URL" "$REPO_BRANCH")"
  archive_path="$(mktemp "${TMPDIR:-/tmp}/ynx-archive.XXXXXX.tar.gz")"

  download_file_with_progress "$archive_url" "$archive_path" "download source archive" 12 17

  print_progress 17 "extract source archive" "unpack repository archive into the local workspace"
  rm -rf "$REPO_DIR"
  top_dir="$(tar -tzf "$archive_path" | head -n1 | cut -d/ -f1)"
  tar -xzf "$archive_path" -C "$WORKDIR"
  extracted_dir="$WORKDIR/$top_dir"
  if [[ ! -d "$extracted_dir" ]]; then
    echo "Archive extract failed: cannot find $extracted_dir" >&2
    rm -f "$archive_path"
    return 1
  fi
  mv "$extracted_dir" "$REPO_DIR"
  rm -f "$archive_path"
}

prepare_workspace() {
  mkdir -p "$WORKDIR"
  REPO_DIR="$WORKDIR/YNX"

  if [[ -d "$REPO_URL" ]]; then
    rm -rf "$REPO_DIR"
    mkdir -p "$(dirname "$REPO_DIR")"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete "${REPO_URL%/}/" "${REPO_DIR}/"
    else
      cp -a "$REPO_URL" "$REPO_DIR"
    fi
    return 0
  fi

  if github_archive_url_from_repo "$REPO_URL" "$REPO_BRANCH" >/dev/null 2>&1; then
    prepare_workspace_from_github_archive
    return 0
  fi

  if [[ -d "$REPO_DIR/.git" ]]; then
    git -C "$REPO_DIR" fetch --progress --depth=1 origin "$REPO_BRANCH" 2>&1 | tr '\r' '\n' | while IFS= read -r line; do
      ynx_ui_stdout "$line"
      pct="$(workspace_progress_from_git_line "$line" || true)"
      if [[ -n "${pct:-}" ]]; then
        print_progress "$pct" "prepare workspace" "git fetch --progress | update the local YNX working copy"
      fi
    done
    git -C "$REPO_DIR" reset --hard "origin/$REPO_BRANCH"
  else
    git clone --progress --depth=1 --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR" 2>&1 | while IFS= read -r line; do
      ynx_ui_stdout "$line"
      pct="$(workspace_progress_from_git_line "$line" || true)"
      if [[ -n "${pct:-}" ]]; then
        print_progress "$pct" "prepare workspace" "git clone --progress | create the local YNX working copy"
      fi
    done
  fi
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
    ynx_ui_stdout "Installing Go ${GO_VERSION} (${os}/${arch})..."
    download_file_with_progress "$url" "$tarball" "download go toolchain" 24 28
    print_progress 28 "extract go toolchain" "unpack go ${GO_VERSION} for ${os}/${arch}"
    rm -rf "$go_dir"
    tar -xzf "$tarball" -C "$toolchain_dir"
  fi
  export PATH="$go_dir/bin:$PATH"
  command -v go >/dev/null 2>&1 || return 1
}

print_progress 6 "check prerequisites" "verify shell, package manager, and base dependencies"
install_missing_base_deps

print_progress 12 "prepare workspace" "prepare or refresh the local YNX repository copy"
prepare_workspace
print_progress 18 "prepare join script" "resolve the repo-local join dispatcher entrypoint"
JOIN_SCRIPT="$REPO_DIR/chain/scripts/v2_join_auto.sh"
if [[ ! -x "$JOIN_SCRIPT" ]]; then
  chmod +x "$JOIN_SCRIPT"
fi

print_progress 24 "prepare toolchain" "ensure go is available if ynxd must be built from source"
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

print_progress 30 "handoff to repo-local join flow" "delegate into the repo-local build, bootstrap, and verify pipeline"
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

YNX_UI_GLOBAL_MODE=1 \
YNX_UI_SUPPRESS_HEADER=1 \
"${CMD[@]}"

print_progress 100 "deployment flow complete" "fresh-machine bootstrap finished"
ynx_ui_note "YNX join flow finished."
