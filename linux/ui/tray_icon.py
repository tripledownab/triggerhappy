"""System tray icon using AppIndicator3."""

import gi
gi.require_version("Gtk", "3.0")

try:
    gi.require_version("AyatanaAppIndicator3", "0.1")
    from gi.repository import AyatanaAppIndicator3 as AppIndicator3
except (ValueError, ImportError):
    try:
        gi.require_version("AppIndicator3", "0.1")
        from gi.repository import AppIndicator3
    except (ValueError, ImportError):
        AppIndicator3 = None

from gi.repository import Gtk


class TrayIcon:
    def __init__(self, app):
        self._app = app
        self._indicator = None
        self._setup()

    def _setup(self):
        if AppIndicator3 is None:
            print("Warning: AppIndicator3 not available. No tray icon.")
            return

        self._indicator = AppIndicator3.Indicator.new(
            "triggerhappy",
            "triggerhappy",
            AppIndicator3.IndicatorCategory.APPLICATION_STATUS,
        )
        self._indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)

        # Try to use our custom icon, fall back to system icon
        self._indicator.set_icon_full("preferences-desktop-keyboard", "Trigger Happy")

        menu = Gtk.Menu()

        settings_item = Gtk.MenuItem(label="Settings...")
        settings_item.connect("activate", lambda _: self._app.show_settings())
        menu.append(settings_item)

        menu.append(Gtk.SeparatorMenuItem())

        quit_item = Gtk.MenuItem(label="Quit")
        quit_item.connect("activate", lambda _: self._app.quit_app())
        menu.append(quit_item)

        menu.show_all()
        self._indicator.set_menu(menu)
