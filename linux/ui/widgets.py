"""Shared GTK widgets: ShortcutPill, KeyCap, status indicator."""

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Pango

from models import KeyCombination


def create_shortcut_pill(combo: KeyCombination) -> Gtk.Box:
    """Create a horizontal box of KeyCap widgets for a key combination."""
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)

    mods = combo.modifiers
    if mods.ctrl:
        box.pack_start(_create_keycap("Ctrl"), False, False, 0)
    if mods.alt:
        box.pack_start(_create_keycap("Alt"), False, False, 0)
    if mods.shift:
        box.pack_start(_create_keycap("Shift"), False, False, 0)
    if mods.super_:
        box.pack_start(_create_keycap("Super"), False, False, 0)

    from models.key_combination import KEY_DISPLAY_MAP
    key_label = KEY_DISPLAY_MAP.get(combo.key_name,
        combo.key_name.upper() if len(combo.key_name) == 1 else combo.key_name.capitalize())
    box.pack_start(_create_keycap(key_label), False, False, 0)

    box.show_all()
    return box


def _create_keycap(label: str) -> Gtk.Label:
    """Create a single keyboard key cap label."""
    lbl = Gtk.Label(label=label)
    lbl.set_name("keycap")
    ctx = lbl.get_style_context()
    ctx.add_class("keycap")
    return lbl


def create_status_dot(active: bool) -> Gtk.DrawingArea:
    """Create a small colored status dot."""
    dot = Gtk.DrawingArea()
    dot.set_size_request(8, 8)

    color = (0.3, 0.8, 0.3) if active else (0.8, 0.3, 0.3)

    def on_draw(widget, cr):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        cr.arc(w / 2, h / 2, 3, 0, 3.14159 * 2)
        cr.set_source_rgb(*color)
        cr.fill()

    dot.connect("draw", on_draw)
    return dot


CSS = """
.keycap {
    background-color: alpha(@theme_fg_color, 0.08);
    border-radius: 3px;
    border: 1px solid alpha(@theme_fg_color, 0.12);
    padding: 1px 4px;
    font-size: 10px;
    font-weight: 500;
    font-family: monospace;
}

.floating-panel {
    background-color: @theme_bg_color;
    border-radius: 12px;
    border: 1px solid alpha(@theme_fg_color, 0.1);
}

.search-entry {
    font-size: 16px;
    font-weight: 300;
    border: none;
    background: transparent;
    box-shadow: none;
}

.result-row {
    padding: 6px 10px;
    border-radius: 6px;
}

.result-row:selected, .result-row-selected {
    background-color: alpha(@theme_selected_bg_color, 0.15);
}

.dim {
    opacity: 0.5;
}

.section-row {
    padding: 8px 10px;
    border-radius: 8px;
    background-color: alpha(@theme_fg_color, 0.04);
}
"""


def load_css():
    """Load the application CSS."""
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS.encode())
    Gtk.StyleContext.add_provider_for_screen(
        __import__("gi").repository.Gdk.Screen.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )
