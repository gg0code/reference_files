#!/usr/bin/env bash
# tmux-pane.sh - keeps the claude pane's tmux title live: "SONNET · PLAN".   Kit v2.13
# Registered on SessionStart, PostModelSwitch, UserPromptSubmit, Stop and SessionEnd.
# Writes the pane option @desc, which the kit's .tmux.conf shows on the pane's top-right border.
# Does nothing outside tmux. Never blocks: always exits 0.
#
#   model : SessionStart "model", PostModelSwitch "to_model" (fires on /model), else the transcript
#   stage : PLAN    plan mode (Shift+Tab), /next, /plan, or the REQ's plan is not yet APPROVED
#           BUILD   the REQ's plan is APPROVED (docs/plans/<ID>.md line 1), or /fix
#           REVIEW  /review, /explain, /audit, /release-check
[ -n "${TMUX_PANE:-}" ] && command -v tmux >/dev/null 2>&1 || { cat >/dev/null; exit 0; }
. "$(dirname "$0")/_lib.sh"

# one python call: event, model, permission mode, first word of the prompt, transcript path
IFS=$'\t' read -r ev model mode cmd tp < <(printf '%s' "$HOOK_INPUT" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
p=(d.get("prompt") or "").strip().split()
print("\t".join(str(x or "-") for x in (d.get("hook_event_name"), d.get("to_model") or d.get("model"),
      d.get("permission_mode"), p[0].lower() if p else "", d.get("transcript_path"))))' 2>/dev/null)

t() { tmux "$@" 2>/dev/null; }
get() { t show -pqv -t "$TMUX_PANE" "$1"; }

if [ "$ev" = "SessionEnd" ]; then
  t set -p -t "$TMUX_PANE" @cc_model ""; t set -p -t "$TMUX_PANE" @cc_stage ""
  t set -p -t "$TMUX_PANE" @desc "CLAUDE NOT RUNNING"; exit 0
fi

# ---- model: claude-sonnet-5-5 / sonnet / claude-opus-5-5[1m] -> SONNET / OPUS
if [ "$model" = "-" ] && [ -z "$(get @cc_model)" ] && [ -f "$tp" ]; then
  model="$(grep -o '"model":"claude-[a-z]*' "$tp" 2>/dev/null | tail -1 | cut -d'"' -f4)"
fi
if [ -n "$model" ] && [ "$model" != "-" ]; then
  name="$(printf '%s' "$model" | tr 'A-Z' 'a-z' | grep -oE 'opus|sonnet|haiku|fable' | head -1)"
  [ -z "$name" ] && name="${model#claude-}" && name="${name%%-*}"
  t set -p -t "$TMUX_PANE" @cc_model "$(printf '%s' "$name" | tr 'a-z' 'A-Z')"
fi

# ---- stage
dir="$(project_dir)"
id="$(git -C "${dir:-.}" branch --show-current 2>/dev/null | grep -oE '(REQ|BUG)-[0-9]{3}' | head -1)"
from_plan() {   # stage implied by the current REQ's plan file
  [ -n "$id" ] || return 0
  if head -1 "$dir/docs/plans/$id.md" 2>/dev/null | grep -q 'Status: APPROVED'; then echo BUILD; else echo PLAN; fi
}
stage="$(get @cc_stage)"
case "$cmd" in
  /next|/plan)                              stage=PLAN ;;
  /review|/explain|/audit|/release-check)   stage=REVIEW ;;
  /fix)                                     stage=BUILD ;;
  /*) ;;                                    # other commands (/status, /model ...) keep the stage
  *)  if [ "$ev" = "SessionStart" ] || { [ "$ev" = "UserPromptSubmit" ] && [ "$stage" != REVIEW ]; }; then
        s="$(from_plan)"; [ -n "$s" ] && stage="$s"
      fi ;;
esac
[ "$mode" = "plan" ] && stage=PLAN
t set -p -t "$TMUX_PANE" @cc_stage "$stage"

m="$(get @cc_model)"
t set -p -t "$TMUX_PANE" @desc "${m:-CLAUDE}${stage:+ · $stage}"
exit 0
