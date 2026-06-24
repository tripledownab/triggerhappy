"""Floating clipboard history window with search and paste."""

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib

from models import ClipboardEntry
from services.clipboard_store import ClipboardStore
from services.paste_simulator import simulate_paste


class ClipboardWindow:
    MAX_VISIBLE = 8

    def __init__(self, clipboard_store: ClipboardStore):
        self._store = clipboard_store
        self._results: list[ClipboardEntry] = []
        self._selected = 0
        self._window: Gtk.Window = None
        self._entry: Gtk.Entry = None
        self._listbox: Gtk.ListBox = None
        self._footer: Gtk.Box = None
        self._count_label: Gtk.Label = None

    @property
    def is_visible(self) -> bool:
        return self._window is not None and self._window.get_visible()

    def toggle(self):
        if self.is_visible:
            self.dismiss()
        else:
            self.show()

    def show(self):
        if self._window is None:
            self._create()

        self._entry.set_text("")
        self._results = self._store.search("")
        self._selected = 0
        self._update_list()

        screen = Gdk.Screen.get_default()
        monitor = screen.get_display().get_primary_monitor()
        if monitor:
            geom = monitor.get_geometry()
            w = 520
            self._window.move(
                geom.x + (geom.width - w) // 2,
                geom.y + int(geom.height * 0.25),
            )

        self._window.show_all()
        self._window.present()
        self._entry.grab_focus()

    def dismiss(self):
        if self._window:
            self._window.hide()

    def _create(self):
        win = Gtk.Window(type=Gtk.WindowType.TOPLEVEL)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_default_size(520, -1)
        win.set_keep_above(True)
        win.set_skip_taskbar_hint(True)
        win.set_type_hint(Gdk.WindowTypeHint.UTILITY)
        win.get_style_context().add_class("floating-panel")

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        vbox.set_margin_top(8)
        vbox.set_margin_bottom(8)

        # Search entry
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        hbox.set_margin_start(16)
        hbox.set_margin_end(16)
        hbox.set_margin_top(6)
        hbox.set_margin_bottom(6)

        icon = Gtk.Image.new_from_icon_name("edit-paste-symbolic", Gtk.IconSize.MENU)
        hbox.pack_start(icon, False, False, 0)

        self._entry = Gtk.Entry()
        self._entry.set_placeholder_text("Search clipboard...")
        self._entry.get_style_context().add_class("search-entry")
        self._entry.set_has_frame(False)
        self._entry.connect("changed", self._on_search_changed)
        self._entry.connect("activate", lambda _: self._paste_selected())
        hbox.pack_start(self._entry, True, True, 0)

        vbox.pack_start(hbox, False, False, 0)
        vbox.pack_start(Gtk.Separator(), False, False, 0)

        # Results list
        self._listbox = Gtk.ListBox()
        self._listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        vbox.pack_start(self._listbox, False, False, 0)

        # Footer
        self._footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        self._footer.set_margin_start(16)
        self._footer.set_margin_end(16)
        self._footer.set_margin_top(4)
        self._footer.set_margin_bottom(4)

        self._count_label = Gtk.Label()
        self._count_label.set_halign(Gtk.Align.START)
        self._count_label.get_style_context().add_class("dim")
        self._footer.pack_start(self._count_label, True, True, 0)

        clear_btn = Gtk.Button(label="Clear All")
        clear_btn.set_relief(Gtk.ReliefStyle.NONE)
        clear_btn.get_style_context().add_class("dim")
        clear_btn.connect("clicked", self._on_clear_all)
        self._footer.pack_end(clear_btn, False, False, 0)

        vbox.pack_start(self._footer, False, False, 0)

        win.add(vbox)
        win.connect("key-press-event", self._on_key_press)
        win.connect("focus-out-event", lambda *_: self.dismiss())

        self._window = win

    def _on_search_changed(self, entry):
        query = entry.get_text()
        self._results = self._store.search(query)
        self._selected = 0
        self._update_list()

    def _on_key_press(self, widget, event):
        key = event.keyval
        if key == Gdk.KEY_Escape:
            self.dismiss()
            return True
        elif key == Gdk.KEY_Down:
            if self._selected < min(len(self._results), self.MAX_VISIBLE) - 1:
                self._selected += 1
                self._update_selection()
            return True
        elif key == Gdk.KEY_Up:
            if self._selected > 0:
                self._selected -= 1
                self._update_selection()
            return True
        elif key == Gdk.KEY_Delete or key == Gdk.KEY_BackSpace:
            # Only delete if entry is empty (not deleting search text)
            if not self._entry.get_text():
                self._delete_selected()
                return True
        return False

    def _paste_selected(self):
        visible = self._results[: self.MAX_VISIBLE]
        if self._selected < len(visible):
            entry = visible[self._selected]
            self._store.copy_to_clipboard(entry)
            self.dismiss()
            GLib.timeout_add(200, lambda: simulate_paste() or False)

    def _delete_selected(self):
        visible = self._results[: self.MAX_VISIBLE]
        if self._selected < len(visible):
            self._store.delete(visible[self._selected].id)
            self._results = self._store.search(self._entry.get_text())
            if self._selected >= len(self._results):
                self._selected = max(0, len(self._results) - 1)
            self._update_list()

    def _on_clear_all(self, button):
        self._store.clear_all()
        self._results = []
        self._selected = 0
        self._update_list()

    def _update_list(self):
        for child in self._listbox.get_children():
            self._listbox.remove(child)

        visible = self._results[: self.MAX_VISIBLE]
        if not visible:
            query = self._entry.get_text() if self._entry else ""
            msg = "No matches" if query else "Clipboard history is empty"
            empty = Gtk.Label(label=msg)
            empty.set_margin_top(16)
            empty.set_margin_bottom(16)
            empty.get_style_context().add_class("dim")
            row = Gtk.ListBoxRow()
            row.add(empty)
            self._listbox.add(row)

        for i, entry in enumerate(visible):
            row = self._create_row(entry, i == self._selected)
            self._listbox.add(row)

        count = len(self._results)
        self._count_label.set_text(f"{count} item{'s' if count != 1 else ''}")

        self._listbox.show_all()
        self._footer.show_all()

    def _update_selection(self):
        for i, row in enumerate(self._listbox.get_children()):
            ctx = row.get_style_context()
            if i == self._selected:
                ctx.add_class("result-row-selected")
            else:
                ctx.remove_class("result-row-selected")

    def _create_row(self, entry: ClipboardEntry, selected: bool) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        row.set_activatable(False)
        ctx = row.get_style_context()
        ctx.add_class("result-row")
        if selected:
            ctx.add_class("result-row-selected")

        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        hbox.set_margin_start(10)
        hbox.set_margin_end(10)
        hbox.set_margin_top(4)
        hbox.set_margin_bottom(4)

        # Content preview + time
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)

        preview = Gtk.Label(label=entry.preview)
        preview.set_halign(Gtk.Align.START)
        preview.set_ellipsize(2)  # Pango.EllipsizeMode.END
        preview.set_max_width_chars(60)
        vbox.pack_start(preview, False, False, 0)

        meta_parts = [entry.relative_time]
        if entry.source_app_name:
            meta_parts.append(entry.source_app_name)
        meta = Gtk.Label(label=" \u00b7 ".join(meta_parts))
        meta.set_halign(Gtk.Align.START)
        meta.get_style_context().add_class("dim")
        vbox.pack_start(meta, False, False, 0)

        hbox.pack_start(vbox, True, True, 0)

        if selected:
            hint = Gtk.Label(label="\u21A9")
            hint.get_style_context().add_class("keycap")
            hbox.pack_end(hint, False, False, 0)

        row.add(hbox)
        return row
