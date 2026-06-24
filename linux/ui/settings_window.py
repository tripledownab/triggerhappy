"""Main settings window — equivalent to macOS MenuBarPanel."""

import os

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

from models import HotkeyBinding, BindingAction, KeyCombination
from services.binding_store import BindingStore
from services.app_indexer import AppIndexer
from services.config_store import ConfigStore
from ui.key_recorder import KeyRecorderWidget
from ui.widgets import create_shortcut_pill, create_status_dot


class SettingsWindow:
    def __init__(self, app):
        self._app = app
        self._window: Gtk.Window = None

    @property
    def is_visible(self) -> bool:
        return self._window is not None and self._window.get_visible()

    def show(self):
        if self._window is None:
            self._create()
        self._refresh()
        self._window.show_all()
        self._window.present()

    def hide(self):
        if self._window:
            self._window.hide()

    def _create(self):
        win = Gtk.Window(title="Trigger Happy")
        win.set_default_size(380, 500)
        win.set_resizable(False)
        win.connect("delete-event", lambda w, e: w.hide() or True)

        self._vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        # Header
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        header.set_margin_start(16)
        header.set_margin_end(16)
        header.set_margin_top(14)
        header.set_margin_bottom(10)

        title = Gtk.Label()
        title.set_markup("<b>Trigger Happy</b>")
        header.pack_start(title, False, False, 0)
        header.pack_start(Gtk.Label(), True, True, 0)  # spacer

        self._status_box = Gtk.Box(spacing=4)
        header.pack_end(self._status_box, False, False, 0)

        self._vbox.pack_start(header, False, False, 0)

        # System hotkey sections
        sections = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        sections.set_margin_start(14)
        sections.set_margin_end(14)
        sections.set_margin_bottom(4)

        self._search_section = self._create_hotkey_section(
            "App Launcher", "edit-find-symbolic",
            self._app.get_system_combo("search"),
            lambda c: self._app.set_system_combo("search", c),
        )
        sections.pack_start(self._search_section, False, False, 0)

        self._cheatsheet_section = self._create_hotkey_section(
            "Cheat Sheet", "view-list-symbolic",
            self._app.get_system_combo("cheat_sheet"),
            lambda c: self._app.set_system_combo("cheat_sheet", c),
        )
        sections.pack_start(self._cheatsheet_section, False, False, 0)

        self._clipboard_section = self._create_hotkey_section(
            "Clipboard History", "edit-paste-symbolic",
            self._app.get_system_combo("clipboard"),
            lambda c: self._app.set_system_combo("clipboard", c),
        )
        sections.pack_start(self._clipboard_section, False, False, 0)

        self._vbox.pack_start(sections, False, False, 0)

        # Binding list
        self._binding_scroll = Gtk.ScrolledWindow()
        self._binding_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self._binding_scroll.set_min_content_height(80)
        self._binding_list = Gtk.ListBox()
        self._binding_list.set_selection_mode(Gtk.SelectionMode.NONE)
        self._binding_scroll.add(self._binding_list)
        self._vbox.pack_start(self._binding_scroll, True, True, 0)

        # Footer
        footer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        footer.set_margin_start(14)
        footer.set_margin_end(14)
        footer.set_margin_top(8)
        footer.set_margin_bottom(10)

        add_btn = Gtk.Button(label="Add Hotkey")
        add_btn.connect("clicked", self._on_add_clicked)
        footer.pack_start(add_btn, False, False, 0)

        footer.pack_start(Gtk.Label(), True, True, 0)  # spacer

        self._login_switch = Gtk.Switch()
        self._login_switch.set_active(self._app.launch_at_login)
        self._login_switch.connect("state-set", self._on_login_toggled)
        login_label = Gtk.Label(label="Login")
        footer.pack_end(self._login_switch, False, False, 0)
        footer.pack_end(login_label, False, False, 4)

        self._vbox.pack_start(footer, False, False, 0)

        win.add(self._vbox)
        self._window = win

    def _refresh(self):
        # Update status
        for child in self._status_box.get_children():
            self._status_box.remove(child)
        dot = create_status_dot(self._app.hotkey_manager.is_active)
        label = Gtk.Label(label="Active" if self._app.hotkey_manager.is_active else "Inactive")
        label.get_style_context().add_class("dim")
        self._status_box.pack_start(dot, False, False, 0)
        self._status_box.pack_start(label, False, False, 0)
        self._status_box.show_all()

        # Update binding list
        for child in self._binding_list.get_children():
            self._binding_list.remove(child)

        bindings = self._app.binding_store.bindings
        if not bindings:
            empty = Gtk.Label(label="No hotkeys yet")
            empty.set_margin_top(30)
            empty.set_margin_bottom(30)
            empty.get_style_context().add_class("dim")
            row = Gtk.ListBoxRow()
            row.add(empty)
            self._binding_list.add(row)
        else:
            for binding in bindings:
                row = self._create_binding_row(binding)
                self._binding_list.add(row)

        self._binding_list.show_all()

    def _create_hotkey_section(self, label, icon_name, current_combo, on_change) -> Gtk.Box:
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        box.get_style_context().add_class("section-row")

        icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.MENU)
        box.pack_start(icon, False, False, 0)

        lbl = Gtk.Label(label=label)
        lbl.get_style_context().add_class("dim")
        box.pack_start(lbl, False, False, 0)

        box.pack_start(Gtk.Label(), True, True, 0)  # spacer

        if current_combo:
            pill = create_shortcut_pill(current_combo)
            box.pack_end(pill, False, False, 0)

        return box

    def _create_binding_row(self, binding: HotkeyBinding) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()

        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        hbox.set_margin_start(14)
        hbox.set_margin_end(14)
        hbox.set_margin_top(4)
        hbox.set_margin_bottom(4)

        # App icon
        icon_name = binding.action.icon_name or "application-x-executable"
        icon = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR)
        hbox.pack_start(icon, False, False, 0)

        # Name + shortcut
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        name = Gtk.Label(label=binding.action.app_name)
        name.set_halign(Gtk.Align.START)
        vbox.pack_start(name, False, False, 0)

        pill = create_shortcut_pill(binding.key_combination)
        pill.set_halign(Gtk.Align.START)
        vbox.pack_start(pill, False, False, 0)
        hbox.pack_start(vbox, True, True, 0)

        # Toggle
        switch = Gtk.Switch()
        switch.set_active(binding.is_enabled)
        switch.set_valign(Gtk.Align.CENTER)
        switch.connect("state-set", lambda w, s, bid=binding.id: self._on_toggle(bid))
        hbox.pack_end(switch, False, False, 0)

        # Delete button
        del_btn = Gtk.Button()
        del_btn.set_image(Gtk.Image.new_from_icon_name("edit-delete-symbolic", Gtk.IconSize.MENU))
        del_btn.set_relief(Gtk.ReliefStyle.NONE)
        del_btn.set_valign(Gtk.Align.CENTER)
        del_btn.connect("clicked", lambda w, bid=binding.id: self._on_delete(bid))
        hbox.pack_end(del_btn, False, False, 0)

        if not binding.is_enabled:
            hbox.set_opacity(0.5)

        row.add(hbox)
        return row

    def _on_toggle(self, binding_id):
        self._app.binding_store.toggle_enabled(binding_id)
        self._refresh()

    def _on_delete(self, binding_id):
        self._app.binding_store.remove(binding_id)
        self._refresh()

    def _on_add_clicked(self, button):
        # Open a simple add dialog
        dialog = AddBindingDialog(self._window, self._app.app_indexer)
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            binding = dialog.get_binding()
            if binding:
                self._app.binding_store.add(binding)
                self._refresh()
        dialog.destroy()

    def _on_login_toggled(self, switch, state):
        self._app.launch_at_login = state


class AddBindingDialog(Gtk.Dialog):
    def __init__(self, parent, indexer: AppIndexer):
        super().__init__(title="Add Hotkey", transient_for=parent, modal=True)
        self.add_buttons("Cancel", Gtk.ResponseType.CANCEL, "Add", Gtk.ResponseType.OK)
        self.set_default_size(350, 280)

        self._indexer = indexer
        self._selected_app = None
        self._combo = None

        box = self.get_content_area()
        box.set_spacing(12)
        box.set_margin_start(16)
        box.set_margin_end(16)
        box.set_margin_top(12)

        # App search
        lbl = Gtk.Label(label="Application")
        lbl.set_halign(Gtk.Align.START)
        lbl.get_style_context().add_class("dim")
        box.pack_start(lbl, False, False, 0)

        self._app_entry = Gtk.Entry()
        self._app_entry.set_placeholder_text("Type to search apps...")
        self._app_entry.connect("changed", self._on_app_search)
        box.pack_start(self._app_entry, False, False, 0)

        self._app_list = Gtk.ListBox()
        self._app_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._app_list.connect("row-selected", self._on_app_selected)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_max_content_height(120)
        scroll.add(self._app_list)
        box.pack_start(scroll, True, True, 0)

        # Key recorder
        lbl2 = Gtk.Label(label="Shortcut")
        lbl2.set_halign(Gtk.Align.START)
        lbl2.get_style_context().add_class("dim")
        box.pack_start(lbl2, False, False, 0)

        self._recorder = KeyRecorderWidget(on_recorded=self._on_key_recorded)
        box.pack_start(self._recorder, False, False, 0)

        box.show_all()

        # Initial app list
        self._update_app_list("")

    def _on_app_search(self, entry):
        self._update_app_list(entry.get_text())

    def _update_app_list(self, query):
        for child in self._app_list.get_children():
            self._app_list.remove(child)

        results = self._indexer.search(query)[:4]
        for app in results:
            row = Gtk.ListBoxRow()
            hbox = Gtk.Box(spacing=8)
            hbox.set_margin_start(8)
            hbox.set_margin_end(8)
            hbox.set_margin_top(2)
            hbox.set_margin_bottom(2)

            icon = Gtk.Image.new_from_icon_name(
                app.icon_name or "application-x-executable",
                Gtk.IconSize.MENU,
            )
            hbox.pack_start(icon, False, False, 0)
            hbox.pack_start(Gtk.Label(label=app.name), False, False, 0)
            row.add(hbox)
            row._app = app
            self._app_list.add(row)

        self._app_list.show_all()

    def _on_app_selected(self, listbox, row):
        if row and hasattr(row, '_app'):
            self._selected_app = row._app
            self._app_entry.set_text(self._selected_app.name)

    def _on_key_recorded(self, combo):
        self._combo = combo

    def get_binding(self):
        if not self._selected_app or not self._combo:
            return None
        return HotkeyBinding(
            key_combination=self._combo,
            action=BindingAction(
                desktop_file=self._selected_app.desktop_file,
                app_name=self._selected_app.name,
                icon_name=self._selected_app.icon_name,
            ),
        )
