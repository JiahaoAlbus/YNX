#!/usr/bin/env bash

if [[ -n "${YNX_UI_LIB_LOADED:-}" ]]; then
  return 0
fi
YNX_UI_LIB_LOADED=1

YNX_UI_KLEIN_BLUE="${YNX_UI_KLEIN_BLUE:-140;196;255}"
YNX_UI_WHITE="${YNX_UI_WHITE:-255;255;255}"
YNX_UI_MUTED="${YNX_UI_MUTED:-188;196;216}"
YNX_UI_WARN="${YNX_UI_WARN:-255;215;120}"
YNX_UI_ERR="${YNX_UI_ERR:-255;120;120}"
YNX_UI_DIM="${YNX_UI_DIM:-130;144;180}"
YNX_UI_GREEN="${YNX_UI_GREEN:-132;214;164}"
YNX_UI_BG_DARK="${YNX_UI_BG_DARK:-26;54;110}"
YNX_UI_BG_PANEL="${YNX_UI_BG_PANEL:-38;78;156}"
YNX_UI_PROGRESS_ACTIVE=0
YNX_UI_PROGRESS_RENDERED_LINES=0
YNX_UI_PROGRESS_PCT=0
YNX_UI_PROGRESS_TEXT=""
YNX_UI_PROGRESS_TIP=""

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

ynx_ui_wrap_plain() {
  local text="$1"
  local width="${2:-72}"
  awk -v width="$width" '
    function emit(line) {
      print line
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

ynx_ui_terminal_width() {
  local cols=100
  if command -v tput >/dev/null 2>&1; then
    cols="$(tput cols 2>/dev/null || echo 100)"
  fi
  if ! [[ "$cols" =~ ^[0-9]+$ ]] || (( cols < 60 )); then
    cols=100
  fi
  echo "$cols"
}

ynx_ui_truncate() {
  local text="$1"
  local max="${2:-40}"
  if (( ${#text} <= max )); then
    printf '%s' "$text"
  elif (( max <= 1 )); then
    printf '%s' "${text:0:max}"
  else
    printf '%s…' "${text:0:$((max - 1))}"
  fi
}

ynx_ui_flush_progress() {
  if [[ "${YNX_UI_COLOR:-0}" -eq 1 && "${YNX_UI_PROGRESS_ACTIVE:-0}" -eq 1 ]]; then
    if (( YNX_UI_PROGRESS_RENDERED_LINES > 0 )); then
      printf '\033[%sA' "$YNX_UI_PROGRESS_RENDERED_LINES"
      local i
      for ((i = 0; i < YNX_UI_PROGRESS_RENDERED_LINES; i++)); do
        printf '\033[2K'
        if (( i < YNX_UI_PROGRESS_RENDERED_LINES - 1 )); then
          printf '\033[1B'
        fi
      done
      if (( YNX_UI_PROGRESS_RENDERED_LINES > 1 )); then
        printf '\033[%sA' $((YNX_UI_PROGRESS_RENDERED_LINES - 1))
      fi
      printf '\r'
    fi
  fi
  YNX_UI_PROGRESS_ACTIVE=0
  YNX_UI_PROGRESS_RENDERED_LINES=0
}

ynx_ui_stdout() {
  local had_progress="${YNX_UI_PROGRESS_ACTIVE:-0}"
  local pct="${YNX_UI_PROGRESS_PCT:-0}"
  local text="${YNX_UI_PROGRESS_TEXT:-}"
  local tip="${YNX_UI_PROGRESS_TIP:-}"
  ynx_ui_flush_progress
  printf '%s\n' "$*"
  if [[ "$had_progress" -eq 1 ]]; then
    ynx_ui_progress "$pct" "$text" "$tip"
  fi
}

ynx_ui_stderr() {
  local had_progress="${YNX_UI_PROGRESS_ACTIVE:-0}"
  local pct="${YNX_UI_PROGRESS_PCT:-0}"
  local text="${YNX_UI_PROGRESS_TEXT:-}"
  local tip="${YNX_UI_PROGRESS_TIP:-}"
  ynx_ui_flush_progress
  printf '%s\n' "$*" >&2
  if [[ "$had_progress" -eq 1 ]]; then
    ynx_ui_progress "$pct" "$text" "$tip"
  fi
}

ynx_ui_banner() {
  ynx_ui_flush_progress
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
  ynx_ui_flush_progress
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
    0) echo "Checking machine prerequisites before any files are changed." ;;
    1) echo 'Preparing the working copy and entry scripts for this machine.' ;;
    2) echo 'Preparing the toolchain or reusing an existing local binary.' ;;
    3) echo "Resolving platform and node role for the local machine." ;;
    4) echo "Building the node binary and preparing runtime paths." ;;
    5) echo "Bootstrapping chain home and validating core config/genesis." ;;
    6) echo "Starting the local node and waiting for RPC readiness." ;;
    7) echo "Forming peers and checking whether block sync has started." ;;
    8) echo "Comparing local height and reference height during sync." ;;
    9) echo 'Final verification and follow-up operator steps.' ;;
    *) echo 'Running the current stage and collecting live status.' ;;
  esac
}

ynx_ui_progress() {
  local pct="$1"
  local text="$2"
  local explicit_tip="${3:-}"
  local width=34
  local filled=$((pct * width / 100))
  local bar_done="" bar_todo="" stage_text tip_text
  local blue white muted reset panel
  blue="$(ynx_ui_color "$YNX_UI_KLEIN_BLUE")"
  white="$(ynx_ui_color "$YNX_UI_WHITE")"
  muted="$(ynx_ui_color "$YNX_UI_MUTED")"
  panel="$(ynx_ui_bg "$YNX_UI_BG_PANEL")"
  reset="$(ynx_ui_reset)"
  YNX_UI_PROGRESS_PCT="$pct"
  YNX_UI_PROGRESS_TEXT="$text"
  if [[ -n "$explicit_tip" ]]; then
    YNX_UI_PROGRESS_TIP="$explicit_tip"
  else
    YNX_UI_PROGRESS_TIP="$(ynx_ui_tip_for_pct "$pct")"
  fi
  if (( filled > 0 )); then
    bar_done="$(printf '%*s' "$filled" '' | tr ' ' '#')"
  fi
  if (( filled < width )); then
    bar_todo="$(printf '%*s' "$((width - filled))" '' | tr ' ' '.')"
  fi
  if [[ "${YNX_UI_COLOR:-0}" -eq 1 ]]; then
    if (( YNX_UI_PROGRESS_ACTIVE == 1 && YNX_UI_PROGRESS_RENDERED_LINES > 0 )); then
      printf '\033[%sA' "$YNX_UI_PROGRESS_RENDERED_LINES"
    fi
    stage_text="$(ynx_ui_truncate "$text" 66)"
    tip_text="$(ynx_ui_truncate "$YNX_UI_PROGRESS_TIP" 66)"
    printf '\033[2K%s%s' "$panel" "$blue"
    ynx_ui_box_line "+" "=" "+" 74
    printf '%s%s' "$panel" "$white"
    ynx_ui_box_text "Current  : $stage_text" 72
    printf '%s%s' "$panel" "$white"
    ynx_ui_box_text "Progress : [${bar_done}${bar_todo}] ${pct}%" 72
    printf '%s%s' "$panel" "$muted"
    ynx_ui_box_text "Detail   : $tip_text" 72
    printf '%s%s' "$panel" "$blue"
    ynx_ui_box_line "+" "=" "+" 74
    printf '%s' "$reset"
    YNX_UI_PROGRESS_ACTIVE=1
    YNX_UI_PROGRESS_RENDERED_LINES=5
  else
    printf '[%s%s] %s%% | %s | %s\n' "$bar_done" "$bar_todo" "$pct" "$text" "$YNX_UI_PROGRESS_TIP"
  fi
}

ynx_ui_kv() {
  ynx_ui_flush_progress
  local key="$1"
  local value="$2"
  local blue white reset
  blue="$(ynx_ui_color "$YNX_UI_KLEIN_BLUE")"
  white="$(ynx_ui_color "$YNX_UI_WHITE")"
  reset="$(ynx_ui_reset)"
  printf '  %s%-18s%s %s%s%s\n' "$blue" "$key" "$reset" "$white" "$value" "$reset"
}

ynx_ui_note() {
  ynx_ui_flush_progress
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
