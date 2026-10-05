"""Per-system rules references, loaded once at startup from REFS_DIR/<id>.md."""

import logging
from pathlib import Path

from rules_lawyer.systems import SYSTEMS

log = logging.getLogger(__name__)


def load_references(refs_dir: Path) -> dict[str, str]:
    """A missing file means that system answers from memory. An unreadable one raises."""
    refs: dict[str, str] = {}
    for system_id in SYSTEMS:
        path = refs_dir / f"{system_id}.md"
        if not path.exists():
            log.info("reference %s: none (answers from memory)", system_id)
            continue
        refs[system_id] = path.read_text(encoding="utf-8")
        log.info("reference %s: %s (%d chars)", system_id, path, len(refs[system_id]))
    return refs
