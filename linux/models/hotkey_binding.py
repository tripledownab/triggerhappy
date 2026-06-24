from dataclasses import dataclass, field
from typing import Optional
import uuid

from .key_combination import KeyCombination


@dataclass
class BindingAction:
    action_type: str = "launch_app"
    desktop_file: str = ""
    app_name: str = ""
    icon_name: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "action_type": self.action_type,
            "desktop_file": self.desktop_file,
            "app_name": self.app_name,
            "icon_name": self.icon_name,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "BindingAction":
        return cls(**d)


@dataclass
class HotkeyBinding:
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    key_combination: KeyCombination = field(default_factory=KeyCombination)
    action: BindingAction = field(default_factory=BindingAction)
    is_enabled: bool = True

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "key_combination": self.key_combination.to_dict(),
            "action": self.action.to_dict(),
            "is_enabled": self.is_enabled,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "HotkeyBinding":
        return cls(
            id=d["id"],
            key_combination=KeyCombination.from_dict(d["key_combination"]),
            action=BindingAction.from_dict(d["action"]),
            is_enabled=d.get("is_enabled", True),
        )
