"""Floating cheat sheet overlay showing all configured hotkeys."""

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

from services.binding_store import BindingStore
from ui.widgets import create_shortcut_pill


class CheatSheetWindow:
    def __init__(self, binding_store: BindingStore):
        self._binding_store = binding_store
        self._window: Gtk.Window = None

    @property
    def is_visible(self) -> bool:
        return self._window is not None and self._window.get_visible()

    def toggle(self):
        if self.is_visible:
            self.dismiss()
        else:
            self.show()

    def show(self):
        # Always recreate for fresh binding data
        self._create()

        screen = Gdk.Screen.get_default()
        monitor = screen.get_display().get_primary_monitor()
        if monitor:
            geom = monitor.get_geometry()
            w = 380
            self._window.move(
                geom.x + (geom.width - w) // 2,
                geom.y + int(geom.height * 0.25),
            )

        self._window.show_all()
        self._window.present()

    def dismiss(self):
        if self._window:
            self._window.destroy()
            self._window = None

    def _create(self):
        win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_default_size(380, -1)
        win.set_keep_above(True)
        win.set_skip_taskbar_hint(True)
        win.set_type_hint(Gdk.WindowTypeHint.UTILITY)
        win.get_style_context().add_class("floating-panel")

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        vbox.set_margin_top(12)
        vbox.set_margin_bottom(12)

        # Header
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        header.set_margin_start(16)
        header.set_margin_end(16)
        header.set_margin_bottom(8)

        title = Gtk.Label(label="Keyboard Shortcuts")
        title.set_halign(Gtk.Align.START)
        title.set_markup("<b>Keyboard Shortcuts</b>")
        header.pack_start(title, True, True, 0)

        hint = Gtk.Label(label="ESC to close")
        hint.get_style_context().add_class("dim")
        header.pack_end(hint, False, False, 0)

        vbox.pack_start(header, False, False, 0)
        vbox.pack_start(Gtk.Separator(), False, False, 0)

        bindings = self._binding_store.bindings
        if not bindings:
            empty = Gtk.Label(label="No hotkeys configured")
            empty.set_margin_top(20)
            empty.set_margin_bottom(20)
            empty.get_style_context().add_class("dim")
            vbox.pack_start(empty, False, False, 0)
        else:
            for binding in bindings:
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
                row.set_margin_start(14)
                row.set_margin_end(14)
                row.set_margin_top(4)
                row.set_margin_bottom(4)

                # App icon
                icon_name = binding.action.icon_name or "application-x-executable"
                icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR)
                row.pack_start(icon, False, False, 0)

                # App name
                name = Gtk.Label(label=binding.action.app_name)
                name.set_halign(Gtk.Align.START)
                row.pack_start(name, True, True, 0)

                # Shortcut pill
                pill = create_shortcut_pill(binding.key_combination)
                row.pack_end(pill, False, False, 0)

                if not binding.is_enabled:
                    row.set_opacity(0.4)

                vbox.pack_start(row, False, False, 0)

        win.add(vbox)
        win.connect("key-press-event", self._on_key_press)
        win.connect("focus-out-event", lambda *_: self.dismiss())

        self._window = win

    def _on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.dismiss()
            return True
        return False
