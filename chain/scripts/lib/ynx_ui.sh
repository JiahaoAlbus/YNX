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
YNX_UI_GREEN="${YNX_UI_GREEN:-132;214;164}"
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

ynx_ui_box_line() {
  local left="$1"
  local fill="$2"
  local right="$3"
  local width="${4:-72}"
  printf '%s%s%s\n' "$left" "$(ynx_ui_line "$width" "$fill")" "$right"
}

ynx_ui_box_text() {
  local text="$1"
  local width="${2:-72}"
  local padded
  padded="$(printf '%-*s' "$width" "$text")"
  printf '| %s |\n' "$padded"
}

ynx_ui_box_wrap() {
  local text="$1"
  local width="${2:-72}"
  awk -v width="$width" '
    function emit(line) {
      printf("| %-*s |\n", width, line)
    }
    {
      line=""
      for (i = 1; i <= NF; i++) {
        word=$i
        if (line == "") {
          line=word
        } else if (length(line) + 1 + length(word) <= width) {
          line=line " " word
        } else {
          emit(line)
          line=word
        }
      }
      if (line != "") emit(line)
      if (NF == 0) emit("")
    }
  ' <<<"$text"
}

ynx_ui_banner() {
  if [[ "${YNX_UI_SUPPRESS_HEADER:-0}" -eq 1 ]]; then
    return 0
  fi
  local title="$1"
  local subtitle="${2:-}"
  local blue white muted reset bg panel
  blue="$(ynx_ui_color "$YNX_UI_KLEIN_BLUE")"
  white="$(ynx_ui_color "$YNX_UI_WHITE")"
  muted="$(ynx_ui_color "$YNX_UI_MUTED")"
  bg="$(ynx_ui_bg "$YNX_UI_BG_DARK")"
  panel="$(ynx_ui_bg "$YNX_UI_BG_PANEL")"
  reset="$(ynx_ui_reset)"
  printf '\n%s' "$bg"
  ynx_ui_box_line "+" "=" "+" 74
  printf '%s%s' "$panel" "$white"
  ynx_ui_box_text "YNX CLI  |  $title" 72
  if [[ -n "$subtitle" ]]; then
    printf '%s%s' "$panel" "$muted"
    ynx_ui_box_wrap "$subtitle" 72
  fi
  printf '%s' "$bg$blue"
  ynx_ui_box_line "+" "=" "+" 74
  printf '%s' "$reset"
}

ynx_ui_plan() {
  if [[ "${YNX_UI_SUPPRESS_HEADER:-0}" -eq 1 ]]; then
    return 0
  fi
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
  ynx_ui_progress "$pct" "$text"
}

ynx_ui_tip_for_pct() {
  local pct="${1:-0}"
  local bucket=$((pct / 10))
  case "$bucket" in
    0) echo "TIP: YNX uses a staged join flow: fetch code, prepare node home, verify RPC, then verify sync." ;;
    1) echo "TIP: The CLI is designed so a fresh machine can install first, then use a stable `ynx join` command." ;;
    2) echo "TIP: `ynx join-plan` is a dry-run mode. It validates the path and shows the flow without mutating the machine." ;;
    3) echo "TIP: A full node is the default role. Validator mode should only be used after funding and operator review." ;;
    4) echo "TIP: The bootstrap stage validates chain-id and genesis before the node is allowed to start." ;;
    5) echo "TIP: P2P readiness is not just port reachability. The node must keep stable peers long enough to sync blocks." ;;
    6) echo "TIP: YNX exposes separate ports for P2P, RPC, API, gRPC, and EVM RPC. Port offset keeps local collisions out." ;;
    7) echo "TIP: Sync verification compares your local block hash with the reference RPC at the same height." ;;
    8) echo "TIP: A machine that can open TCP is still not necessarily accepted as a healthy peer by the network." ;;
    9) echo "TIP: When join completes, the same `ynx` CLI can be used again for repeatable node bring-up on new machines." ;;
    *) echo "TIP: YNX is converging toward a single operator experience: install once, then use `ynx help` and `ynx join`." ;;
  esac
}

ynx_ui_progress() {
  local pct="$1"
  local text="$2"
  local width=36
  local filled=$((pct * width / 100))
  local bar_done="" bar_todo=""
  local blue white dim green reset panel
  blue="$(ynx_ui_color "$YNX_UI_KLEIN_BLUE")"
  white="$(ynx_ui_color "$YNX_UI_WHITE")"
  dim="$(ynx_ui_color "$YNX_UI_DIM")"
  green="$(ynx_ui_color "$YNX_UI_GREEN")"
  panel="$(ynx_ui_bg "$YNX_UI_BG_PANEL")"
  reset="$(ynx_ui_reset)"
  if (( filled > 0 )); then
    bar_done="$(printf '%*s' "$filled" '' | tr ' ' '=')"
  fi
  if (( filled < width )); then
    bar_todo="$(printf '%*s' "$((width - filled))" '' | tr ' ' '.')"
  fi
  echo
  printf '%s%s' "$panel" "$blue"
  ynx_ui_box_line "+" "-" "+" 74
  printf '%s%s' "$panel" "$white"
  ynx_ui_box_text "Stage    : $text" 72
  printf '%s' "$panel"
  ynx_ui_box_text "Progress : [${bar_done}${bar_todo}] ${pct}%" 72
  printf '%s%s' "$panel" "$green"
  ynx_ui_box_wrap "$(ynx_ui_tip_for_pct "$pct")" 72
  printf '%s%s' "$panel" "$blue"
  ynx_ui_box_line "+" "-" "+" 74
  printf '%s' "$reset"
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
