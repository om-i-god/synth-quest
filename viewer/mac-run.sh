#!/usr/bin/env bash
# Run the Synth Quest viewer on this Mac in a window. Connect from the
# norns by setting ~/.config/synth-quest/viewer.conf on the norns to
# this Mac's LAN IP and port 7777, then toggle PARAMS > video stream > on.
#
# Usage:  ./mac-run.sh             # 4x window, 512x256
#         ./mac-run.sh --scale 6   # bigger window
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

# 1) Use the venv at viewer/.venv if present (Homebrew Python on macOS
#    refuses --user/--system installs; venv is the supported path). Create
#    one on first run.
PY="python3"
if [ -x "$DIR/.venv/bin/python3" ]; then
  PY="$DIR/.venv/bin/python3"
elif ! python3 -c "import pygame" 2>/dev/null; then
  echo "Creating viewer/.venv and installing pygame + numpy (one-time)..."
  python3 -m venv "$DIR/.venv"
  "$DIR/.venv/bin/pip" install --quiet --upgrade pip
  "$DIR/.venv/bin/pip" install --quiet pygame numpy
  PY="$DIR/.venv/bin/python3"
fi

# 2) Show the LAN IP the norns should target. Only prints when stdout is
#    a TTY (i.e. when launched from Terminal); silent when invoked by
#    the .app launcher (Dock click) so we don't spam the system log.
if [ -t 1 ]; then
  IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo unknown)"
  echo
  echo "  Mac LAN IP:  ${IP}"
  echo "  Listen port: 7777"
  echo
  echo "  On the norns, run once:"
  echo "    mkdir -p ~/.config/synth-quest"
  echo "    echo '${IP}:7777' > ~/.config/synth-quest/viewer.conf"
  echo "  then PARAMS > SYNTH QUEST -- video > video stream > on"
  echo
fi

# 3) Launch the viewer (windowed, default 4x scale).
exec "$PY" "$DIR/synth-quest-viewer.py" --windowed --port 7777 "$@"
