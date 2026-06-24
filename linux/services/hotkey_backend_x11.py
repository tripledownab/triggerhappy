"""X11 global hotkey backend using python-xlib XGrabKey."""

import threading
from typing import Callable, Optional

from Xlib import X, XK, display as xdisplay, error as xerror


# Lock modifier masks to handle NumLock/CapsLock/ScrollLock
_LOCK_MASKS = [0]


def _init_lock_masks(display):
    """Build all combinations of lock modifiers."""
    global _LOCK_MASKS

    num_lock = 0
    scroll_lock = 0

    # Find NumLock and ScrollLock modifier masks
    modmap = display.get_modifier_mapping()
    num_lock_code = display.keysym_to_keycode(XK.XK_Num_Lock)
    scroll_lock_code = display.keysym_to_keycode(XK.XK_Scroll_Lock)

    for i, codes in enumerate(modmap):
        for code in codes:
            if code == num_lock_code:
                num_lock = 1 << i
            elif code == scroll_lock_code:
                scroll_lock = 1 << i

    _LOCK_MASKS = [
        0,
        X.LockMask,  # CapsLock
        num_lock,
        scroll_lock,
        X.LockMask | num_lock,
        X.LockMask | scroll_lock,
        num_lock | scroll_lock,
        X.LockMask | num_lock | scroll_lock,
    ]


class HotkeyRegistration:
    def __init__(self, keycode: int, modmask: int, callback: Callable):
        self.keycode = keycode
        self.modmask = modmask
        self.callback = callback


class X11HotkeyBackend:
    def __init__(self):
        self._display: Optional[xdisplay.Display] = None
        self._root = None
        self._registrations: dict[str, HotkeyRegistration] = {}
        self._thread: Optional[threading.Thread] = None
        self._running = False
        self._glib_idle_add: Optional[Callable] = None

    def set_idle_add(self, idle_add: Callable):
        """Set the GLib.idle_add function for main-thread dispatch."""
        self._glib_idle_add = idle_add

    def start(self):
        self._display = xdisplay.Display()
        self._root = self._display.screen().root
        _init_lock_masks(self._display)

        self._root.change_attributes(event_mask=X.KeyPressMask)
        self._running = True
        self._thread = threading.Thread(target=self._event_loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False
        self.ungrab_all()
        if self._display:
            self._display.close()
            self._display = None

    def grab_key(self, key_name: str, modmask: int, callback: Callable) -> Optional[str]:
        if not self._display:
            return None

        keysym = XK.string_to_keysym(key_name)
        if keysym == 0:
            # Try capitalized for single letters
            keysym = XK.string_to_keysym(key_name.capitalize())
        if keysym == 0:
            return None

        keycode = self._display.keysym_to_keycode(keysym)
        if keycode == 0:
            return None

        reg_id = f"{keycode}_{modmask}"
        self._registrations[reg_id] = HotkeyRegistration(keycode, modmask, callback)

        # Grab with all lock modifier combinations
        for lock in _LOCK_MASKS:
            try:
                self._root.grab_key(
                    keycode,
                    modmask | lock,
                    True,  # owner_events
                    X.GrabModeAsync,
                    X.GrabModeAsync,
                )
            except xerror.BadAccess:
                pass  # Another app already grabbed this combo

        self._display.flush()
        return reg_id

    def ungrab_key(self, reg_id: str):
        reg = self._registrations.pop(reg_id, None)
        if not reg or not self._display:
            return
        for lock in _LOCK_MASKS:
            try:
                self._root.ungrab_key(reg.keycode, reg.modmask | lock)
            except Exception:
                pass
        self._display.flush()

    def ungrab_all(self):
        for reg_id in list(self._registrations.keys()):
            self.ungrab_key(reg_id)

    def _event_loop(self):
        while self._running:
            try:
                if not self._display:
                    break
                count = self._display.pending_events()
                if count == 0:
                    # Small sleep to avoid busy-wait
                    import time
                    time.sleep(0.01)
                    # Process pending events with a timeout
                    self._display.next_event()
                    continue

                for _ in range(count):
                    event = self._display.next_event()
                    if event.type == X.KeyPress:
                        self._handle_key(event)
            except Exception:
                if not self._running:
                    break

    def _handle_key(self, event):
        keycode = event.detail
        # Strip lock modifiers to match our registration
        state = event.state & ~(X.LockMask | X.Mod2Mask | X.Mod5Mask)

        reg_id = f"{keycode}_{state}"
        reg = self._registrations.get(reg_id)
        if reg and self._glib_idle_add:
            self._glib_idle_add(reg.callback)
