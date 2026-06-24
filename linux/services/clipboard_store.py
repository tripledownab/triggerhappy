"""Clipboard history monitoring and persistence."""

import subprocess
from datetime import datetime
from typing import Callable, Optional

from models import ClipboardEntry
from services.config_store import ConfigStore
from services.display_server import DisplayServer, get_display_server


class ClipboardStore:
    MAX_ENTRIES = 50
    MAX_CONTENT_LENGTH = 10_000

    def __init__(self, config: ConfigStore):
        self._config = config
        self._entries: list[ClipboardEntry] = []
        self._last_content: Optional[str] = None
        self._timer_id: Optional[int] = None
        self._display_server = get_display_server()
        self._load()

    @property
    def entries(self) -> list[ClipboardEntry]:
        return self._entries

    def start_monitoring(self):
        from gi.repository import GLib
        self._last_content = self._read_clipboard()
        self._timer_id = GLib.timeout_add(500, self._check_clipboard)

    def stop_monitoring(self):
        if self._timer_id is not None:
            from gi.repository import GLib
            GLib.source_remove(self._timer_id)
            self._timer_id = None

    def search(self, query: str) -> list[ClipboardEntry]:
        if not query:
            return self._entries
        q = query.lower()
        return [e for e in self._entries if q in e.content.lower()]

    def delete(self, entry_id: str):
        self._entries = [e for e in self._entries if e.id != entry_id]
        self._save()

    def clear_all(self):
        self._entries.clear()
        self._save()

    def copy_to_clipboard(self, entry: ClipboardEntry):
        """Copy content to system clipboard."""
        self._last_content = entry.content  # prevent re-adding
        try:
            if self._display_server == DisplayServer.WAYLAND:
                proc = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
                proc.communicate(entry.content.encode())
            else:
                proc = subprocess.Popen(
                    ["xclip", "-selection", "clipboard"],
                    stdin=subprocess.PIPE,
                )
                proc.communicate(entry.content.encode())
        except FileNotFoundError:
            pass

    def _read_clipboard(self) -> Optional[str]:
        try:
            if self._display_server == DisplayServer.WAYLAND:
                result = subprocess.run(
                    ["wl-paste", "--no-newline"],
                    capture_output=True, text=True, timeout=1,
                )
            else:
                result = subprocess.run(
                    ["xclip", "-selection", "clipboard", "-o"],
                    capture_output=True, text=True, timeout=1,
                )
            if result.returncode == 0:
                return result.stdout
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
        return None

    def _check_clipboard(self) -> bool:
        content = self._read_clipboard()
        if content is None or not content.strip():
            return True  # keep polling

        if content == self._last_content:
            return True

        self._last_content = content

        # Deduplicate
        if self._entries and self._entries[0].content == content:
            return True

        # Cap content length
        if len(content) > self.MAX_CONTENT_LENGTH:
            content = content[: self.MAX_CONTENT_LENGTH]

        entry = ClipboardEntry(
            content=content,
            timestamp=datetime.now().isoformat(),
        )

        self._entries.insert(0, entry)
        if len(self._entries) > self.MAX_ENTRIES:
            self._entries = self._entries[: self.MAX_ENTRIES]
        self._save()

        return True  # keep polling

    def _save(self):
        self._config.set("clipboard_history", [e.to_dict() for e in self._entries])

    def _load(self):
        data = self._config.get("clipboard_history", [])
        self._entries = [ClipboardEntry.from_dict(d) for d in data]
