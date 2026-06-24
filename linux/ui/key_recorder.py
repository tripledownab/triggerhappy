"""Key combination recording widget for GTK3."""

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

from models import KeyCombination, ModifierSet


class KeyRecorderWidget(Gtk.Box):
    """A widget that captures key combinations when clicked."""

    def __init__(self, on_recorded=None):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self._combo = None
        self._is_recording = False
        self._on_recorded = on_recorded
        self._error_msg = None

        # Display area
        self._button = Gtk.Button(label="Click to record shortcut")
        self._button.connect("clicked", self._start_recording)
        self.pack_start(self._button, False, False, 0)

        # Error label
        self._error_label = Gtk.Label()
        self._error_label.set_halign(Gtk.Align.START)
        self._error_label.set_no_show_all(True)
        self.pack_start(self._error_label, False, False, 0)

    @property
    def combination(self) -> KeyCombination:
        return self._combo

    @combination.setter
    def combination(self, combo: KeyCombination):
        self._combo = combo
        if combo:
            self._button.set_label(combo.display_string)
        else:
            self._button.set_label("Click to record shortcut")

    def _start_recording(self, button):
        self._is_recording = True
        self._error_label.hide()
        self._button.set_label("Press shortcut...")

        # Grab keyboard focus
        self._button.grab_focus()
        self._key_handler = self._button.connect("key-press-event", self._on_key_press)

    def _stop_recording(self):
        self._is_recording = False
        if hasattr(self, '_key_handler'):
            self._button.disconnect(self._key_handler)

    def _on_key_press(self, widget, event):
        if not self._is_recording:
            return False

        keyval = event.keyval
        state = event.state

        # Escape cancels
        if keyval == Gdk.KEY_Escape:
            self._stop_recording()
            if self._combo:
                self._button.set_label(self._combo.display_string)
            else:
                self._button.set_label("Click to record shortcut")
            return True

        # Ignore bare modifier keys
        if keyval in (Gdk.KEY_Shift_L, Gdk.KEY_Shift_R,
                      Gdk.KEY_Control_L, Gdk.KEY_Control_R,
                      Gdk.KEY_Alt_L, Gdk.KEY_Alt_R,
                      Gdk.KEY_Super_L, Gdk.KEY_Super_R,
                      Gdk.KEY_Meta_L, Gdk.KEY_Meta_R):
            return True

        mods = ModifierSet(
            ctrl=bool(state & Gdk.ModifierType.CONTROL_MASK),
            alt=bool(state & Gdk.ModifierType.MOD1_MASK),
            shift=bool(state & Gdk.ModifierType.SHIFT_MASK),
            super_=bool(state & Gdk.ModifierType.MOD4_MASK),
        )

        # Must have a real modifier
        if not mods.has_real_modifier:
            self._show_error("Must include Ctrl, Alt, or Super")
            return True

        key_name = Gdk.keyval_name(keyval).lower() if Gdk.keyval_name(keyval) else ""
        if not key_name:
            return True

        combo = KeyCombination(key_name=key_name, modifiers=mods)

        if combo.is_hard_reserved:
            self._show_error(f"{combo.display_string} cannot be overridden")
            return True

        self._combo = combo
        self._stop_recording()
        self._button.set_label(combo.display_string)

        conflict = combo.known_conflict
        if conflict:
            self._show_error(f"May conflict with: {conflict}", warning=True)
        else:
            self._error_label.hide()

        if self._on_recorded:
            self._on_recorded(combo)

        return True

    def _show_error(self, msg: str, warning: bool = False):
        color = "#cc8800" if warning else "#cc0000"
        self._error_label.set_markup(f'<span foreground="{color}" size="small">{msg}</span>')
        self._error_label.show()
