#!/usr/bin/env python3
"""Trigger Happy — Linux global hotkey manager and app launcher."""

import os
import sys
import signal

# Add the linux directory to the path so imports work
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib

from models import KeyCombination, ModifierSet
from services.config_store import ConfigStore
from services.binding_store import BindingStore
from services.app_indexer import AppIndexer
from services.clipboard_store import ClipboardStore
from services.display_server import get_display_server, DisplayServer
from services.hotkey_backend_x11 import X11HotkeyBackend
from services.hotkey_manager import HotkeyManager
from services import app_launcher

from ui.tray_icon import TrayIcon
from ui.settings_window import SettingsWindow
from ui.search_window import SearchWindow
from ui.cheatsheet_window import CheatSheetWindow
from ui.clipboard_window import ClipboardWindow
from ui.widgets import load_css

# Default system hotkeys
DEFAULT_COMBOS = {
    "search": KeyCombination("space", ModifierSet(alt=True)),
    "cheat_sheet": KeyCombination("slash", ModifierSet(alt=True)),
    "clipboard": KeyCombination("v", ModifierSet(alt=True)),
}


class TriggerHappyApp:
    def __init__(self):
        self.config_store = ConfigStore()
        self.binding_store = BindingStore(self.config_store)
        self.app_indexer = AppIndexer()
        self.clipboard_store = ClipboardStore(self.config_store)

        # Display server detection
        self.display_server = get_display_server()
        print(f"Display server: {self.display_server.value}")

        # Hotkey backend (X11 for now)
        backend = X11HotkeyBackend()
        backend.set_idle_add(GLib.idle_add)
        self.hotkey_manager = HotkeyManager(backend)

        # Window controllers
        self.settings_window = SettingsWindow(self)
        self.search_window = SearchWindow(self.app_indexer)
        self.cheatsheet_window = CheatSheetWindow(self.binding_store)
        self.clipboard_window = ClipboardWindow(self.clipboard_store)

        # Tray icon
        self.tray_icon = TrayIcon(self)

    def run(self):
        load_css()

        # Start hotkey manager
        self.hotkey_manager.start()

        # Register system hotkeys
        self._register_system_hotkeys()

        # Register user hotkeys
        self._register_user_hotkeys()
        self.binding_store.on_change = self._register_user_hotkeys

        # Start clipboard monitoring
        self.clipboard_store.start_monitoring()

        print("Trigger Happy is running. Look for the tray icon.")
        Gtk.main()

    def quit_app(self):
        self.hotkey_manager.stop()
        self.clipboard_store.stop_monitoring()
        Gtk.main_quit()

    def show_settings(self):
        self.settings_window.show()

    # MARK: - System Hotkey Combos

    def get_system_combo(self, name: str) -> KeyCombination:
        data = self.config_store.get(f"system_hotkey_{name}")
        if data:
            return KeyCombination.from_dict(data)
        return DEFAULT_COMBOS.get(name, KeyCombination("space", ModifierSet(alt=True)))

    def set_system_combo(self, name: str, combo: KeyCombination):
        self.config_store.set(f"system_hotkey_{name}", combo.to_dict())
        self._register_system_hotkeys()

    # MARK: - Launch at Login

    @property
    def launch_at_login(self) -> bool:
        autostart_path = self._autostart_path()
        return os.path.exists(autostart_path)

    @launch_at_login.setter
    def launch_at_login(self, enabled: bool):
        path = self._autostart_path()
        if enabled:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            script_path = os.path.abspath(__file__)
            with open(path, "w") as f:
                f.write(f"""[Desktop Entry]
Type=Application
Name=Trigger Happy
Exec=python3 {script_path}
Icon=preferences-desktop-keyboard
X-GNOME-Autostart-enabled=true
Comment=Global hotkey manager and app launcher
""")
        else:
            try:
                os.remove(path)
            except FileNotFoundError:
                pass

    def _autostart_path(self) -> str:
        config_home = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
        return os.path.join(config_home, "autostart", "triggerhappy.desktop")

    # MARK: - Hotkey Registration

    def _register_system_hotkeys(self):
        # Unregister old system hotkeys
        for name in ("sys_search", "sys_cheatsheet", "sys_clipboard"):
            self.hotkey_manager.unregister(name)

        combos = {
            "sys_search": (self.get_system_combo("search"), lambda: self.search_window.toggle()),
            "sys_cheatsheet": (self.get_system_combo("cheat_sheet"), lambda: self.cheatsheet_window.toggle()),
            "sys_clipboard": (self.get_system_combo("clipboard"), lambda: self.clipboard_window.toggle()),
        }

        for reg_id, (combo, callback) in combos.items():
            self.hotkey_manager.register(reg_id, combo, callback)

    def _register_user_hotkeys(self):
        # Unregister all user hotkeys (keep system ones)
        user_ids = [k for k in self.hotkey_manager._registrations if not k.startswith("sys_")]
        for uid in user_ids:
            self.hotkey_manager.unregister(uid)

        for binding in self.binding_store.bindings:
            if binding.is_enabled:
                desktop_file = binding.action.desktop_file
                self.hotkey_manager.register(
                    binding.id,
                    binding.key_combination,
                    lambda df=desktop_file: app_launcher.launch(df),
                )


def main():
    # Allow Ctrl+C to quit
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    app = TriggerHappyApp()
    app.run()


if __name__ == "__main__":
    main()
