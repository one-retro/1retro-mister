#!/usr/bin/env python3
"""Generate the MiSTer Downloader database for 1Retro.

Reads a published GitHub release, hashes the three files it carries, and writes
the two artifacts Downloader and users fetch:

    db.json.zip            the database itself
    downloader_1retro.ini  the drop-in that points at it, copied to the card

Both land in --out, which in CI is a checkout of the orphan `db` branch, so a
run that changes nothing leaves no diff to commit.

Two rules from the database format drive the shape of this script:

  * Every URL must be immutable bytes, because the database pins an MD5 next to
    it. Release asset URLs are; anything with "latest" in it is not.
  * db_id and db_url are chosen once and never change. Changing either makes
    Downloader treat the contents as a second, unrelated database: files get
    duplicated on the SD card and cleanup stops working.

Standard library only, so the workflow needs no install step.
"""

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.request
import zipfile
from pathlib import Path

DB_ID = "1retro"
DEFAULT_REPO = "one-retro/1retro-mister"

# Asset name in the release -> path it installs to, relative to /media/fat.
# Dropping the wrappers in Scripts/ is what puts them in the MiSTer Scripts
# menu. The state directory (/media/fat/1retro) is deliberately absent: the
# database owns what it lists, and Downloader deletes what leaves it, so listing
# the state dir would let an upgrade take the sync state and logs with it.
INSTALL = {
    "1retro-mister": "Scripts/1retro-mister",
    "1retro.sh": "Scripts/1retro.sh",
}


def api(url):
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def release(repo, tag):
    """The release to build from: a specific tag, or the latest published one."""
    path = f"tags/{tag}" if tag else "latest"
    return api(f"https://api.github.com/repos/{repo}/releases/{path}")


def fetch(url):
    request = urllib.request.Request(url, headers={"Accept": "application/octet-stream"})
    with urllib.request.urlopen(request) as response:
        return response.read()


def build_files(rel):
    """Hash every expected asset, or fail saying which one is missing.

    Failing loudly matters more than it looks: a database that silently drops a
    file tells Downloader to delete that file from every SD card that has it.
    """
    assets = {asset["name"]: asset for asset in rel.get("assets", [])}
    missing = [name for name in INSTALL if name not in assets]
    if missing:
        sys.exit(f"release {rel['tag_name']} is missing: {', '.join(missing)}")

    files = {}
    for name, target in INSTALL.items():
        data = fetch(assets[name]["browser_download_url"])
        files[target] = {
            "hash": hashlib.md5(data).hexdigest(),
            "size": len(data),
            "url": assets[name]["browser_download_url"],
        }
        print(f"{target}: {files[target]['hash']} ({files[target]['size']} bytes)")
    return files


def previous(path):
    if not path.exists():
        return None
    with zipfile.ZipFile(path) as archive:
        return json.loads(archive.read("db.json"))


def write_zip(path, name, data):
    """Write a one-entry zip whose bytes depend only on its contents.

    Zip records a mtime per entry, so without a fixed date_time every run would
    produce a different file and push a commit that changes nothing.
    """
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o644 << 16
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(info, data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", DEFAULT_REPO))
    parser.add_argument("--tag", default=None, help="release tag (default: the latest release)")
    parser.add_argument("--out", default="out", type=Path)
    args = parser.parse_args()

    db_url = f"https://raw.githubusercontent.com/{args.repo}/db/db.json.zip"
    args.out.mkdir(parents=True, exist_ok=True)
    db_zip = args.out / "db.json.zip"

    rel = release(args.repo, args.tag)
    print(f"building from {rel['tag_name']}")
    files = build_files(rel)

    # Keep the old timestamp when nothing else moved, so an unchanged database
    # stays byte-identical and the workflow has nothing to push.
    old = previous(db_zip)
    timestamp = old["timestamp"] if old and old.get("files") == files else int(time.time())

    db = {
        "v": 1,
        "db_id": DB_ID,
        "timestamp": timestamp,
        "files": files,
        "folders": {"Scripts/": {}},
    }
    write_zip(db_zip, "db.json", json.dumps(db, indent=2, sort_keys=True))

    # The drop-in goes out as a plain file rather than a zip. Nothing reads it
    # as an archive: Downloader wants the ini itself on the card, so a zip only
    # adds an unzip step on a device that may not have one, where a plain file
    # makes the whole install a single wget.
    ini_path = args.out / f"downloader_{DB_ID}.ini"
    ini_path.write_text(f"[{DB_ID}]\ndb_url = {db_url}\ndescription = 1Retro save sync\n")

    # The db branch is only ever updated by writing into a checkout of it, so a
    # file we stop writing would sit there forever unless it is removed.
    stale_zip = args.out / f"downloader_{DB_ID}.zip"
    if stale_zip.exists():
        stale_zip.unlink()
        print(f"removed {stale_zip}")

    print(f"wrote {db_zip} and {ini_path}")


if __name__ == "__main__":
    main()
