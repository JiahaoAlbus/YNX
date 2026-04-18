#!/usr/bin/env bash

if [[ -n "${YNX_UI_LIB_LOADED:-}" ]]; then
  return 0
fi
YNX_UI_LIB_LOADED=1

YNX_UI_KLEIN_BLUE="${YNX_UI_KLEIN_BLUE:-86;156;214}"
YNX_UI_WHITE="${YNX_UI_WHITE:-255;255;255}"
YNX_UI_MUTED="${YNX_UI_MUTED:-188;196;216}"
YNX_UI_WARN="${YNX_UI_WARN:-255;215;120}"
YNX_UI_ERR="${YNX_UI_ERR:-255;120;120}"
YNX_UI_DIM="${YNX_UI_DIM:-130;144;180}"
YNX_UI_BG_DARK="${YNX_UI_BG_DARK:-18;22;28}"
YNX_UI_BG_PANEL="${YNX_UI_BG_PANEL:-24;30;38}"

ynx_ui_init() {
  if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]]; then
    YNX_UI_COLOR=1
  else
    YNX_UI_COLOR=0
  fi
}

ynx_ui_color() {
  local rgb="$1"
  if [[ "${YNX_UI_COLOR:-0}" -eq 1 ]]; then
    printf '\033[38;2;%sm' "$rgb"
  fi
}

ynx_ui_reset() {
  if [[ "${YNX_UI_COLOR:-0}" -eq 1 ]]; then
    printf '\033[0m'
  fi
}

ynx_ui_bg() {
  local rgb="$1"
  if [[ "${YNX_UI_COLOR:-0}" -eq 1 ]]; then
    printf '\033[48;2;%sm' "$rgb"
  fi
}

ynx_ui_line() {
  local count="${1:-72}"
  local ch="${2:--}"
  printf '%*s' "$count" '' | tr ' ' "$ch"
}

ynx_ui_banner() {
  local title="$1"
  local subtitle="${2:-}"
  local blue white muted reset bg panel
  blue="$(ynx_ui_color "$YNX_UI_KLEIN_BLUE")"
  white="$(ynx_ui_color "$YNX_UI_WHITE")"
  muted="$(ynx_ui_color "$YNX_UI_MUTED")"
  bg="$(ynx_ui_bg "$YNX_UI_BG_DARK")"
  panel="$(ynx_ui_bg "$YNX_UI_BG_PANEL")"
  reset="$(ynx_ui_reset)"
  printf '\n%s%s%s%s\n' "$bg" "$blue" "$(ynx_ui_line 72 '=')" "$reset"
  printf '%s%sYNX %s%s%s\n' "$panel" "$white" "$blue" "$title" "$reset"
  if [[ -n "$subtitle" ]]; then
    printf '%s%s%s\n' "$panel$muted" "$subtitle" "$reset"
  fi
  printf '%s%s%s%s\n' "$bg" "$blue" "$(ynx_ui_line 72 '=')" "$reset"
}

ynx_ui_plan() {
  local title="$1"
  shift
  local idx=1
  local blue white dim reset
  blue="$(ynx_ui_color "$YNX_UI_KLEIN_BLUE")"
  white="$(ynx_ui_color "$YNX_UI_WHITE")"
  dim="$(ynx_ui_color "$YNX_UI_DIM")"
  reset="$(ynx_ui_reset)"
  printf '%sExecution Plan%s %s%s%s\n' "$blue" "$reset" "$dim" "$title" "$reset"
  for item in "$@"; do
    printf '  %s%02d%s %s%s%s\n' "$blue" "$idx" "$reset" "$white" "$item" "$reset"
    idx=$((idx + 1))
  done
  echo
}

ynx_ui_step() {
  local current="$1"
  local total="$2"
  local text="$3"
  local pct=$((current * 100 / total))
  local width=28
  local filled=$((pct * width / 100))
  local bar_done="" bar_todo=""
  local blue white dim reset
  blue="$(ynx_ui_color "$YNX_UI_KLEIN_BLUE")"
  white="$(ynx_ui_color "$YNX_UI_WHITE")"
  dim="$(ynx_ui_color "$YNX_UI_DIM")"
  reset="$(ynx_ui_reset)"
  if (( filled > 0 )); then
    bar_done="$(printf '%*s' "$filled" '' | tr ' ' '=')"
  fi
  if (( filled < width )); then
    bar_todo="$(printf '%*s' "$((width - filled))" '' | tr ' ' '.')"
  fi
  echo
  printf '%s[%d/%d]%s %s[%s%s]%s %s%3d%%%s %s%s%s\n' \
    "$blue" "$current" "$total" "$reset" \
    "$blue" "$bar_done" "$dim$bar_todo" "$reset" \
    "$white" "$pct" "$reset" \
    "$white" "$text" "$reset"
}

ynx_ui_kv() {
  local key="$1"
  local value="$2"
  local blue white reset
  blue="$(ynx_ui_color "$YNX_UI_KLEIN_BLUE")"
  white="$(ynx_ui_color "$YNX_UI_WHITE")"
  reset="$(ynx_ui_reset)"
  printf '  %s%-18s%s %s%s%s\n' "$blue" "$key" "$reset" "$white" "$value" "$reset"
}

ynx_ui_note() {
  local text="$1"
  local color="$YNX_UI_MUTED"
  if [[ "${2:-}" == "warn" ]]; then
    color="$YNX_UI_WARN"
  elif [[ "${2:-}" == "error" ]]; then
    color="$YNX_UI_ERR"
  fi
  local c reset
  c="$(ynx_ui_color "$color")"
  reset="$(ynx_ui_reset)"
  printf '%s%s%s\n' "$c" "$text" "$reset"
}
