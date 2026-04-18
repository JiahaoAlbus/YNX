#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${YNX_REPO_URL:-https://github.com/JiahaoAlbus/YNX.git}"
REPO_BRANCH="${YNX_REPO_BRANCH:-main}"
INSTALL_ROOT="${YNX_INSTALL_ROOT:-$HOME/.ynx-cli}"
BIN_DIR="${YNX_BIN_DIR:-$HOME/.local/bin}"
TARGET_LINK="$BIN_DIR/ynx"
REPO_DIR="$INSTALL_ROOT/YNX"

need_bin() {
  command -v "$1" >/dev/null 2>&1
}

pkg_install() {
  local packages="$1"
  local prefix=""
  if [[ "$(id -u)" -ne 0 ]] && need_bin sudo; then
    prefix="sudo"
  fi

  if need_bin apt-get; then
    ${prefix} apt-get update -y && ${prefix} apt-get install -y $packages
  elif need_bin dnf; then
    ${prefix} dnf install -y $packages
  elif need_bin yum; then
    ${prefix} yum install -y $packages
  elif need_bin pacman; then
    ${prefix} pacman -Sy --noconfirm $packages
  elif need_bin zypper; then
    ${prefix} zypper --non-interactive install $packages
  elif need_bin apk; then
    ${prefix} apk add --no-cache $packages
  elif need_bin brew; then
    brew install $packages
  else
    echo "Unsupported package manager. Please install git, bash, curl, jq manually." >&2
    exit 1
  fi
}

ensure_base_deps() {
  local missing=()
  local dep
  for dep in git bash curl jq; do
    if ! need_bin "$dep"; then
      missing+=("$dep")
    fi
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    return 0
  fi
  pkg_install "git bash curl jq ca-certificates"
}

ensure_on_path() {
  case ":$PATH:" in
    *":$BIN_DIR:"*) return 0 ;;
  esac

  local shell_rc="$HOME/.profile"
  if [[ -n "${SHELL:-}" && "${SHELL##*/}" == "zsh" ]]; then
    shell_rc="$HOME/.zshrc"
  elif [[ -n "${SHELL:-}" && "${SHELL##*/}" == "bash" ]]; then
    shell_rc="$HOME/.bashrc"
  fi

  mkdir -p "$(dirname "$shell_rc")"
  touch "$shell_rc"
  if ! grep -Fq "export PATH=\"$BIN_DIR:\$PATH\"" "$shell_rc"; then
    printf '\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >>"$shell_rc"
  fi
}

echo "Installing YNX CLI..."
ensure_base_deps
mkdir -p "$INSTALL_ROOT" "$BIN_DIR"

if [[ -d "$REPO_URL" ]]; then
  rm -rf "$REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  if need_bin rsync; then
    rsync -a --delete "${REPO_URL%/}/" "${REPO_DIR}/"
  else
    cp -a "$REPO_URL" "$REPO_DIR"
  fi
elif [[ -d "$REPO_DIR/.git" ]]; then
  git -C "$REPO_DIR" fetch --depth=1 origin "$REPO_BRANCH"
  git -C "$REPO_DIR" reset --hard "origin/$REPO_BRANCH"
else
  rm -rf "$REPO_DIR"
  git clone --depth=1 --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi

chmod +x "$REPO_DIR/ynx" "$REPO_DIR/ynxjoin" \
  "$REPO_DIR/scripts/install_ynx.sh" \
  "$REPO_DIR/chain/scripts/v2_join_one_line.sh" \
  "$REPO_DIR/chain/scripts/v2_join_auto.sh" \
  "$REPO_DIR/chain/scripts/v2_join_and_verify.sh" \
  "$REPO_DIR/chain/scripts/v2_validator_bootstrap.sh"

ln -sfn "$REPO_DIR/ynx" "$TARGET_LINK"
ensure_on_path

echo
echo "Installed YNX CLI:"
echo "  repo: $REPO_DIR"
echo "  bin : $TARGET_LINK"
echo
echo "Next:"
echo "  export PATH=\"$BIN_DIR:\$PATH\""
echo "  ynx help"
echo "  ynx join"
