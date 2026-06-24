"""Launch applications from .desktop files."""

import subprocess

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio


def launch(desktop_file: str):
    """Launch an app from its .desktop file path."""
    try:
        app_info = Gio.DesktopAppInfo.new_from_filename(desktop_file)
        if app_info:
            app_info.launch([], None)
        else:
            # Fallback: try opening the desktop file directly
            subprocess.Popen(["gtk-launch", desktop_file.split("/")[-1].replace(".desktop", "")])
    except Exception as e:
        print(f"Failed to launch {desktop_file}: {e}")
