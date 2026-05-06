#!/usr/bin/env bash
# Install the Synth Quest HDMI viewer on a norns / Raspberry Pi.
# Run on the Pi (not your dev mac):  ssh into norns, cd here, ./install.sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE="synth-quest-viewer.service"

echo "Synth Quest viewer install"
echo "  source: $DIR"

# 1) Python deps
if ! python3 -c "import pygame" 2>/dev/null; then
  echo "Installing pygame..."
  sudo apt-get update
  sudo apt-get install -y python3-pygame
fi

# 2) Install systemd unit
echo "Installing $SERVICE -> /etc/systemd/system/"
sudo cp "$DIR/$SERVICE" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE"

# 3) Start it now (will sit at the splash until synth-quest connects)
sudo systemctl restart "$SERVICE"

echo
echo "Done. Status:"
sudo systemctl status "$SERVICE" --no-pager | head -10
echo
echo "If you see a splash on the HDMI display, you're good."
echo "Synth Quest will auto-connect when the script runs."
echo
echo "Disable with:    sudo systemctl disable --now $SERVICE"
echo "View logs with:  journalctl --user-unit $SERVICE -f   (or as root)"
