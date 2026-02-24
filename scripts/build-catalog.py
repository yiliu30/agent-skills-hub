#!/usr/bin/env python3
"""
Build a unified catalog.json from all skill sources (third-party submodules + custom).

Scans for SKILL.md files, extracts frontmatter metadata, and writes catalog.json.

Usage:
    python scripts/build-catalog.py
    python scripts/build-catalog.py --output catalog.json
"""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = REPO_ROOT / "catalog.json"

# Directories to scan and their source_type
SCAN_DIRS = [
    # (directory, source_type, source_name_override)
    (REPO_ROOT / "third-party", "third-party", None),
    (REPO_ROOT / "custom", "custom", "custom"),
]


def parse_frontmatter(skill_md_path: Path) -> dict:
    """Extract YAML-like frontmatter from a SKILL.md file."""
    text = skill_md_path.read_text(encoding="utf-8")

    # Match frontmatter between --- delimiters (also supports ```skill blocks)
    # Pattern 1: standard YAML frontmatter
    fm_match = re.search(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not fm_match:
        # Pattern 2: ```skill block frontmatter
        fm_match = re.search(r"```skill\s*\n---\s*\n(.*?)\n---", text, re.DOTALL)

    if not fm_match:
        return {}

    frontmatter = {}
    for line in fm_match.group(1).strip().splitlines():
        line = line.strip()
        if ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip().strip("'\"")
            if value:
                frontmatter[key] = value

    return frontmatter


def find_skills_in_dir(base_dir: Path) -> list[tuple[Path, Path]]:
    """Find all SKILL.md files under a directory. Returns (skill_md_path, skill_dir)."""
    results = []
    if not base_dir.exists():
        return results
    for skill_md in sorted(base_dir.rglob("SKILL.md")):
        results.append((skill_md, skill_md.parent))
    return results


def detect_source_name(skill_dir: Path, base_dir: Path) -> str:
    """Detect the source name from the submodule directory name."""
    rel = skill_dir.relative_to(base_dir)
    parts = rel.parts
    if len(parts) >= 1:
        return parts[0]
    return "unknown"


def has_assets(skill_dir: Path) -> bool:
    """Check if a skill directory has non-SKILL.md files (assets, templates, scripts)."""
    for item in skill_dir.iterdir():
        if item.name != "SKILL.md" and item.name != "LICENSE.txt":
            return True
    return False


def build_catalog(output_path: Path = DEFAULT_OUTPUT) -> dict:
    """Scan all skill directories and build the catalog."""
    skills = []
    seen_names = {}  # track duplicates: name -> list of sources

    for scan_dir, source_type, source_name_override in SCAN_DIRS:
        for skill_md, skill_dir in find_skills_in_dir(scan_dir):
            fm = parse_frontmatter(skill_md)
            name = fm.get("name", skill_dir.name)
            description = fm.get("description", "")
            license_info = fm.get("license", "")

            if source_name_override:
                source = source_name_override
            else:
                source = detect_source_name(skill_dir, scan_dir)

            rel_path = str(skill_dir.relative_to(REPO_ROOT))

            skill_entry = {
                "name": name,
                "description": description,
                "source": source,
                "source_type": source_type,
                "path": rel_path,
                "has_assets": has_assets(skill_dir),
            }
            if license_info:
                skill_entry["license"] = license_info

            # Track duplicates
            if name in seen_names:
                seen_names[name].append(source)
                skill_entry["duplicate_of"] = seen_names[name][0]
            else:
                seen_names[name] = [source]

            skills.append(skill_entry)

    # Sort by source_type (custom first) then name
    skills.sort(key=lambda s: (0 if s["source_type"] == "custom" else 1, s["name"]))

    catalog = {
        "version": "1.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "total_skills": len(skills),
        "sources": {
            "custom": len([s for s in skills if s["source_type"] == "custom"]),
            "third-party": len([s for s in skills if s["source_type"] == "third-party"]),
        },
        "duplicates": [
            {"name": name, "found_in": sources}
            for name, sources in seen_names.items()
            if len(sources) > 1
        ],
        "skills": skills,
    }

    output_path.write_text(
        json.dumps(catalog, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    return catalog


def print_summary(catalog: dict) -> None:
    """Print a human-readable summary."""
    print(f"✅ Catalog built: {catalog['total_skills']} skills total")
    print(f"   Custom:      {catalog['sources']['custom']}")
    print(f"   Third-party: {catalog['sources']['third-party']}")
    if catalog["duplicates"]:
        print(f"\n⚠️  Duplicates detected ({len(catalog['duplicates'])}):")
        for dup in catalog["duplicates"]:
            print(f"   - '{dup['name']}' found in: {', '.join(dup['found_in'])}")
    print(f"\n📄 Written to: {DEFAULT_OUTPUT}")


if __name__ == "__main__":
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUTPUT
    catalog = build_catalog(output)
    print_summary(catalog)
