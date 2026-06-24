from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
import uuid


@dataclass
class ClipboardEntry:
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    content: str = ""
    timestamp: str = field(default_factory=lambda: datetime.now().isoformat())
    source_app_name: Optional[str] = None

    @property
    def preview(self) -> str:
        trimmed = " ".join(self.content.strip().splitlines())
        return trimmed[:80] + "..." if len(trimmed) > 80 else trimmed

    @property
    def relative_time(self) -> str:
        try:
            dt = datetime.fromisoformat(self.timestamp)
        except ValueError:
            return ""
        delta = datetime.now() - dt
        seconds = int(delta.total_seconds())
        if seconds < 60:
            return "just now"
        elif seconds < 3600:
            m = seconds // 60
            return f"{m}m ago"
        elif seconds < 86400:
            h = seconds // 3600
            return f"{h}h ago"
        else:
            d = seconds // 86400
            return f"{d}d ago"

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "content": self.content,
            "timestamp": self.timestamp,
            "source_app_name": self.source_app_name,
        }

    @classmethod
    def from_dict(cls, d: dict) -> "ClipboardEntry":
        return cls(**d)
