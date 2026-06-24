import os
from enum import Enum


class DisplayServer(Enum):
    X11 = "x11"
    WAYLAND = "wayland"


def get_display_server() -> DisplayServer:
    """Detect whether we are running on X11 or Wayland."""
    # User override
    backend = os.environ.get("GDK_BACKEND", "").lower()
    if backend == "x11":
        return DisplayServer.X11
    if backend == "wayland":
        return DisplayServer.WAYLAND

    session = os.environ.get("XDG_SESSION_TYPE", "").lower()
    if session == "wayland":
        return DisplayServer.WAYLAND
    if session == "x11":
        return DisplayServer.X11

    if os.environ.get("WAYLAND_DISPLAY"):
        return DisplayServer.WAYLAND

    return DisplayServer.X11  # default fallback
