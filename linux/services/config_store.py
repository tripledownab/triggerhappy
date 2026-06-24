import json
import os
import tempfile
from typing import Any


class ConfigStore:
    """JSON-based persistence in ~/.config/triggerhappy/."""

    def __init__(self):
        config_home = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
        self._dir = os.path.join(config_home, "triggerhappy")
        self._path = os.path.join(self._dir, "config.json")
        os.makedirs(self._dir, exist_ok=True)
        self._data = self._load()

    def get(self, key: str, default: Any = None) -> Any:
        return self._data.get(key, default)

    def set(self, key: str, value: Any):
        self._data[key] = value
        self._save()

    def _load(self) -> dict:
        if not os.path.exists(self._path):
            return {}
        try:
            with open(self._path, "r") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return {}

    def _save(self):
        # Atomic write: write to temp file then rename
        fd, tmp_path = tempfile.mkstemp(dir=self._dir, suffix=".json.tmp")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump(self._data, f, indent=2)
            os.replace(tmp_path, self._path)
        except Exception:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            raise
