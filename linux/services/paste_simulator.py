"""Simulate Ctrl+V paste via xdotool (X11) or wtype (Wayland)."""

import subprocess

from services.display_server import DisplayServer, get_display_server


def simulate_paste():
    ds = get_display_server()
    try:
        if ds == DisplayServer.WAYLAND:
            subprocess.Popen(["wtype", "-M", "ctrl", "v", "-m", "ctrl"])
        else:
            subprocess.Popen(["xdotool", "key", "--clearmodifiers", "ctrl+v"])
    except FileNotFoundError:
        pass
