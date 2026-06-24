"""Floating app launcher window with fuzzy search."""

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk, GLib, Gio

from services.app_indexer import AppIndexer, IndexedApp
from services import app_launcher
from ui.widgets import create_shortcut_pill


class SearchWindow:
    MAX_VISIBLE = 6

    def __init__(self, indexer: AppIndexer):
        self._indexer = indexer
        self._results: list[IndexedApp] = []
        self._selected = 0
        self._window: Gtk.Window = None
        self._entry: Gtk.Entry = None
        self._listbox: Gtk.ListBox = None
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
        self._results = self._indexer.search("")
        self._selected = 0
        self._update_list()

        screen = Gdk.Screen.get_default()
        monitor = screen.get_display().get_primary_monitor()
        if monitor:
            geom = monitor.get_geometry()
            w, h = 500, self._window.get_size()[1]
            self._window.move(
                geom.x + (geom.width - w) // 2,
                geom.y + int(geom.height * 0.3),
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
        win.set_default_size(500, -1)
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

        icon = Gtk.Image.new_from_icon_name("edit-find-symbolic", Gtk.IconSize.MENU)
        hbox.pack_start(icon, False, False, 0)

        self._entry = Gtk.Entry()
        self._entry.set_placeholder_text("Search apps...")
        self._entry.get_style_context().add_class("search-entry")
        self._entry.set_has_frame(False)
        self._entry.connect("changed", self._on_search_changed)
        self._entry.connect("activate", lambda _: self._launch_selected())
        hbox.pack_start(self._entry, True, True, 0)

        vbox.pack_start(hbox, False, False, 0)
        vbox.pack_start(Gtk.Separator(), False, False, 0)

        # Results list
        self._listbox = Gtk.ListBox()
        self._listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        vbox.pack_start(self._listbox, False, False, 0)

        # Count label
        self._count_label = Gtk.Label()
        self._count_label.set_halign(Gtk.Align.START)
        self._count_label.set_margin_start(16)
        self._count_label.set_margin_bottom(4)
        self._count_label.get_style_context().add_class("dim")
        vbox.pack_start(self._count_label, False, False, 0)

        win.add(vbox)

        # Key handling
        win.connect("key-press-event", self._on_key_press)
        win.connect("focus-out-event", lambda *_: self.dismiss())

        self._window = win

    def _on_search_changed(self, entry):
        query = entry.get_text()
        self._results = self._indexer.search(query)
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
        return False

    def _launch_selected(self):
        visible = self._results[: self.MAX_VISIBLE]
        if self._selected < len(visible):
            app_launcher.launch(visible[self._selected].desktop_file)
            self.dismiss()

    def _update_list(self):
        for child in self._listbox.get_children():
            self._listbox.remove(child)

        visible = self._results[: self.MAX_VISIBLE]
        for i, app in enumerate(visible):
            row = self._create_row(app, i == self._selected)
            self._listbox.add(row)

        remaining = len(self._results) - self.MAX_VISIBLE
        if remaining > 0:
            self._count_label.set_text(f"{remaining} more...")
            self._count_label.show()
        else:
            self._count_label.hide()

        self._listbox.show_all()

    def _update_selection(self):
        for i, row in enumerate(self._listbox.get_children()):
            ctx = row.get_style_context()
            if i == self._selected:
                ctx.add_class("result-row-selected")
            else:
                ctx.remove_class("result-row-selected")

    def _create_row(self, app: IndexedApp, selected: bool) -> Gtk.ListBoxRow:
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

        # App icon
        if app.icon_name:
            icon = Gtk.Image.new_from_icon_name(app.icon_name, Gtk.IconSize.LARGE_TOOLBAR)
        else:
            icon = Gtk.Image.new_from_icon_name("application-x-executable", Gtk.IconSize.LARGE_TOOLBAR)
        hbox.pack_start(icon, False, False, 0)

        # App name
        label = Gtk.Label(label=app.name)
        label.set_halign(Gtk.Align.START)
        label.set_ellipsize(Pango.EllipsizeMode.END) if hasattr(label, 'set_ellipsize') else None
        hbox.pack_start(label, True, True, 0)

        if selected:
            hint = Gtk.Label(label="\u21A9")
            hint.get_style_context().add_class("keycap")
            hbox.pack_end(hint, False, False, 0)

        row.add(hbox)
        row.connect("activate", lambda _: self._launch_app(app))
        return row

    def _launch_app(self, app: IndexedApp):
        app_launcher.launch(app.desktop_file)
        self.dismiss()


# Need Pango for ellipsize
try:
    from gi.repository import Pango
except ImportError:
    pass
