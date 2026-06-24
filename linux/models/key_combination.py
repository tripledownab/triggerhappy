from dataclasses import dataclass, field
from typing import Optional

# GDK key name → display string
KEY_DISPLAY_MAP = {
    "space": "Space", "return": "Return", "escape": "Esc",
    "tab": "Tab", "backspace": "Backspace", "delete": "Del",
    "up": "\u2191", "down": "\u2193", "left": "\u2190", "right": "\u2192",
    "home": "Home", "end": "End", "page_up": "PgUp", "page_down": "PgDn",
    "minus": "-", "equal": "=", "bracketleft": "[", "bracketright": "]",
    "backslash": "\\", "semicolon": ";", "apostrophe": "'",
    "comma": ",", "period": ".", "slash": "/", "grave": "`",
}

HARD_RESERVED = {
    ("tab", True, False, False, False),      # Alt+Tab
    ("f4", True, False, False, False),       # Alt+F4
    ("delete", False, True, True, False),    # Ctrl+Alt+Delete
}

KNOWN_CONFLICTS = {
    ("t", False, True, True, False): "GNOME Terminal",
    ("space", True, False, False, False): "GNOME Activities",
    ("l", False, False, False, True): "Lock screen",
    ("f2", True, False, False, False): "GNOME run dialog",
    ("d", False, False, False, True): "Show desktop",
    ("q", False, True, False, True): "Log out",
}


@dataclass
class ModifierSet:
    alt: bool = False
    ctrl: bool = False
    shift: bool = False
    super_: bool = False

    @property
    def display_string(self) -> str:
        parts = []
        if self.ctrl:
            parts.append("Ctrl")
        if self.alt:
            parts.append("Alt")
        if self.shift:
            parts.append("Shift")
        if self.super_:
            parts.append("Super")
        return "+".join(parts)

    @property
    def has_real_modifier(self) -> bool:
        return self.alt or self.ctrl or self.super_

    def to_dict(self) -> dict:
        return {"alt": self.alt, "ctrl": self.ctrl, "shift": self.shift, "super": self.super_}

    @classmethod
    def from_dict(cls, d: dict) -> "ModifierSet":
        return cls(alt=d.get("alt", False), ctrl=d.get("ctrl", False),
                   shift=d.get("shift", False), super_=d.get("super", False))

    @property
    def x11_mask(self) -> int:
        """Return X11 modifier mask bits."""
        from Xlib import X
        mask = 0
        if self.ctrl:
            mask |= X.ControlMask
        if self.alt:
            mask |= X.Mod1Mask
        if self.shift:
            mask |= X.ShiftMask
        if self.super_:
            mask |= X.Mod4Mask
        return mask


@dataclass
class KeyCombination:
    key_name: str  # GDK key name, e.g. "space", "a", "slash"
    modifiers: ModifierSet = field(default_factory=ModifierSet)

    @property
    def display_string(self) -> str:
        mod = self.modifiers.display_string
        key = KEY_DISPLAY_MAP.get(self.key_name, self.key_name.upper() if len(self.key_name) == 1 else self.key_name.capitalize())
        return f"{mod}+{key}" if mod else key

    @property
    def is_hard_reserved(self) -> bool:
        key = (self.key_name.lower(), self.modifiers.alt, self.modifiers.ctrl,
               self.modifiers.shift, self.modifiers.super_)
        return key in HARD_RESERVED

    @property
    def known_conflict(self) -> Optional[str]:
        key = (self.key_name.lower(), self.modifiers.alt, self.modifiers.ctrl,
               self.modifiers.shift, self.modifiers.super_)
        return KNOWN_CONFLICTS.get(key)

    def to_dict(self) -> dict:
        return {"key_name": self.key_name, "modifiers": self.modifiers.to_dict()}

    @classmethod
    def from_dict(cls, d: dict) -> "KeyCombination":
        return cls(key_name=d["key_name"], modifiers=ModifierSet.from_dict(d["modifiers"]))

    def __eq__(self, other):
        if not isinstance(other, KeyCombination):
            return False
        return self.key_name == other.key_name and self.modifiers == other.modifiers

    def __hash__(self):
        return hash((self.key_name, self.modifiers.alt, self.modifiers.ctrl,
                      self.modifiers.shift, self.modifiers.super_))
