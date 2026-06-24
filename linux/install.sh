#!/bin/bash
set -e

echo "=== Trigger Happy — Linux Installer ==="

# System dependencies
echo "Installing system dependencies..."
sudo apt update
sudo apt install -y \
    python3-gi python3-gi-cairo gir1.2-gtk-3.0 \
    gir1.2-ayatanaappindicator3-0.1 \
    xdotool xclip wl-clipboard wtype

# Python dependencies
echo "Installing Python dependencies..."
pip3 install --user python-xlib

# Desktop entry for app launcher visibility
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cat > "$DESKTOP_DIR/triggerhappy.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Trigger Happy
Comment=Global hotkey manager and app launcher
Exec=python3 $SCRIPT_DIR/triggerhappy.py
Icon=preferences-desktop-keyboard
Categories=Utility;
Terminal=false
EOF

echo ""
echo "=== Installation complete ==="
echo "Run with: python3 $SCRIPT_DIR/triggerhappy.py"
echo ""
echo "Default hotkeys:"
echo "  Alt+Space  — App Launcher"
echo "  Alt+/      — Cheat Sheet"
echo "  Alt+V      — Clipboard History"
