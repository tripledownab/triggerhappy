"""Scan .desktop files and provide fuzzy search for installed applications."""

import configparser
import os
from dataclasses import dataclass
from typing import Optional


@dataclass
class IndexedApp:
    name: str
    desktop_file: str
    icon_name: Optional[str]
    exec_line: str

    def __hash__(self):
        return hash(self.desktop_file)

    def __eq__(self, other):
        return isinstance(other, IndexedApp) and self.desktop_file == other.desktop_file


class AppIndexer:
    def __init__(self):
        self.apps: list[IndexedApp] = []
        self.reindex()

    def reindex(self):
        found: dict[str, IndexedApp] = {}

        search_dirs = self._get_search_dirs()
        for d in search_dirs:
            if not os.path.isdir(d):
                continue
            for fname in os.listdir(d):
                if not fname.endswith(".desktop"):
                    continue
                path = os.path.join(d, fname)
                if path in found:
                    continue
                app = self._parse_desktop(path)
                if app:
                    found[path] = app

        self.apps = sorted(found.values(), key=lambda a: a.name.lower())

    def search(self, query: str) -> list[IndexedApp]:
        if not query:
            return self.apps

        q = query.lower()
        scored = []
        for app in self.apps:
            score = self._fuzzy_score(q, app.name.lower())
            if score is not None:
                scored.append((app, score))

        scored.sort(key=lambda x: x[1], reverse=True)
        return [app for app, _ in scored]

    def _get_search_dirs(self) -> list[str]:
        dirs = [
            "/usr/share/applications",
            "/usr/local/share/applications",
            os.path.expanduser("~/.local/share/applications"),
            "/var/lib/flatpak/exports/share/applications",
            "/var/lib/snapd/desktop/applications",
        ]

        # Add from XDG_DATA_DIRS
        xdg = os.environ.get("XDG_DATA_DIRS", "/usr/share:/usr/local/share")
        for d in xdg.split(":"):
            app_dir = os.path.join(d, "applications")
            if app_dir not in dirs:
                dirs.append(app_dir)

        return dirs

    def _parse_desktop(self, path: str) -> Optional[IndexedApp]:
        parser = configparser.ConfigParser(interpolation=None)
        try:
            parser.read(path, encoding="utf-8")
        except Exception:
            return None

        section = "Desktop Entry"
        if not parser.has_section(section):
            return None

        if parser.get(section, "Type", fallback="") != "Application":
            return None
        if parser.getboolean(section, "NoDisplay", fallback=False):
            return None
        if parser.getboolean(section, "Hidden", fallback=False):
            return None

        name = parser.get(section, "Name", fallback="")
        if not name:
            return None

        return IndexedApp(
            name=name,
            desktop_file=path,
            icon_name=parser.get(section, "Icon", fallback=None),
            exec_line=parser.get(section, "Exec", fallback=""),
        )

    def _fuzzy_score(self, query: str, target: str) -> Optional[int]:
        qi = 0
        score = 0
        consecutive = 0
        last_match = -1

        for ti, tc in enumerate(target):
            if qi >= len(query):
                break
            if tc == query[qi]:
                qi += 1
                score += 1
                if ti == last_match + 1:
                    consecutive += 1
                    score += consecutive * 3
                else:
                    consecutive = 0
                if ti == 0:
                    score += 10
                elif ti > 0 and target[ti - 1] in " -.":
                    score += 5
                last_match = ti

        if qi != len(query):
            return None

        if target.startswith(query):
            score += 20
        score += max(0, 20 - (len(target) - len(query)))
        return score
