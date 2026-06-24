from typing import Callable, Optional

from models import HotkeyBinding, KeyCombination
from services.config_store import ConfigStore


class BindingStore:
    """Manages user hotkey bindings with persistence."""

    def __init__(self, config: ConfigStore):
        self._config = config
        self._bindings: list[HotkeyBinding] = []
        self.on_change: Optional[Callable] = None
        self._load()

    @property
    def bindings(self) -> list[HotkeyBinding]:
        return self._bindings

    def add(self, binding: HotkeyBinding):
        self._bindings.append(binding)
        self._save()

    def remove(self, binding_id: str):
        self._bindings = [b for b in self._bindings if b.id != binding_id]
        self._save()

    def update(self, binding: HotkeyBinding):
        for i, b in enumerate(self._bindings):
            if b.id == binding.id:
                self._bindings[i] = binding
                break
        self._save()

    def toggle_enabled(self, binding_id: str):
        for b in self._bindings:
            if b.id == binding_id:
                b.is_enabled = not b.is_enabled
                break
        self._save()

    def has_conflict(self, combo: KeyCombination, exclude_id: Optional[str] = None) -> bool:
        return any(
            b.key_combination == combo and b.id != exclude_id
            for b in self._bindings
        )

    def _save(self):
        self._config.set("bindings", [b.to_dict() for b in self._bindings])
        if self.on_change:
            self.on_change()

    def _load(self):
        data = self._config.get("bindings", [])
        self._bindings = [HotkeyBinding.from_dict(d) for d in data]
