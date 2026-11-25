#!/bin/sh
# tmux-light.sh <pane_id> [colour] — black text on a light background, and back to the colour the pane had.
# colour: white (default), mustard, pink, mint, sky, lavender, peach.
# Picking the colour that is already on restores the pane; picking another light colour switches to it.
# Saves the pane's own window-style / window-active-style (set by select-pane -P or the
# right-click menu) and restores them; a pane with no colour of its own goes back to the
# global dim/active look.
p="${1:?usage: tmux-light.sh <pane_id> [white|mustard|pink|mint|sky|lavender|peach]}"
case "${2:-white}" in
  mustard)  BG='#e3b52e' ;;
  pink)     BG='#f7c6d9' ;;
  mint)     BG='#cdeedc' ;;
  sky)      BG='#cfe5ff' ;;
  lavender) BG='#e2d9fb' ;;
  peach)    BG='#ffd8b0' ;;
  *)        BG='#ffffff' ;;
esac
LIGHT="fg=#1a1a1a,bg=$BG"

get() { tmux show -pqv -t "$p" "$1"; }

restore() {  # $1 = saved value, $2 = option name
  if [ -n "$1" ]; then tmux set -p -t "$p" "$2" "$1"; else tmux set -pu -t "$p" "$2"; fi
}

# Light only if we turned it light AND nobody recoloured it since (e.g. via the menu).
lit=0
[ "$(get @light)" = 1 ] && [ "$(get window-style)" = "$(get @light_style)" ] && lit=1

if [ "$lit" = 1 ] && [ "$(get @light_bg)" = "$BG" ]; then
  # Same colour picked again: back to the pane's own colour.
  restore "$(get @orig_ws)"  window-style
  restore "$(get @orig_was)" window-active-style
  tmux set -pu -t "$p" pane-colours
  tmux set -pu -t "$p" @light
  tmux set -pu -t "$p" @light_bg
  exit 0
fi

if [ "$lit" = 0 ]; then
  # First switch to a light colour: remember the pane's own colour, and re-map the 16 ANSI
  # colours for this pane only, to darker shades that read on a light background
  # (pale yellow/cyan/white/grey from ls, git, pytest, uvicorn, watch...).
  # Index:  0 black 1 red 2 green 3 yellow 4 blue 5 magenta 6 cyan 7 white, 8-15 bright.
  set -- "$p" \
    0 '#1a1a1a'  1 '#b3261e'  2 '#1a7f37'  3 '#7a4f00'  4 '#0550ae'  5 '#8250df'  6 '#0b6e79'  7 '#4d4d4d' \
    8 '#5e5e5e'  9 '#cf222e' 10 '#116329' 11 '#6b4300' 12 '#0969da' 13 '#a2369b' 14 '#06727e' 15 '#2b2b2b'
  shift
  while [ $# -ge 2 ]; do tmux set -p -t "$p" "pane-colours[$1]" "$2"; shift 2; done
  tmux set -p -t "$p" @orig_ws  "$(get window-style)"
  tmux set -p -t "$p" @orig_was "$(get window-active-style)"
fi

tmux set -p -t "$p" window-style "$LIGHT"
tmux set -p -t "$p" window-active-style "$LIGHT"
tmux set -p -t "$p" @light_style "$(get window-style)"
tmux set -p -t "$p" @light_bg "$BG"
tmux set -p -t "$p" @light 1
