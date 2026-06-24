"""Hotkey manager that abstracts over X11/Wayland backends."""

from typing import Callable, Optional

from models import KeyCombination
from services.hotkey_backend_x11 import X11HotkeyBackend


class HotkeyManager:
    def __init__(self, backend: X11HotkeyBackend):
        self._backend = backend
        self._registrations: dict[str, str] = {}  # binding_id -> backend_handle
        self.is_active = False

    def start(self):
        self._backend.start()
        self.is_active = True

    def stop(self):
        self._backend.stop()
        self.is_active = False

    def register(self, reg_id: str, combo: KeyCombination, callback: Callable) -> bool:
        handle = self._backend.grab_key(
            combo.key_name,
            combo.modifiers.x11_mask,
            callback,
        )
        if handle:
            self._registrations[reg_id] = handle
            return True
        return False

    def unregister(self, reg_id: str):
        handle = self._registrations.pop(reg_id, None)
        if handle:
            self._backend.ungrab_key(handle)

    def unregister_all(self):
        for reg_id in list(self._registrations.keys()):
            self.unregister(reg_id)

    def reregister_all(self, bindings, callback_factory: Callable):
        """Re-register all enabled bindings. callback_factory(binding) -> callable."""
        self.unregister_all()
        for binding in bindings:
            if binding.is_enabled:
                cb = callback_factory(binding)
                self.register(binding.id, binding.key_combination, cb)
