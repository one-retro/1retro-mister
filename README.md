# 1Retro for MiSTer FPGA

Cloud save sync for the [MiSTer FPGA](https://mister-devel.github.io/MkDocs_MiSTer/).
Saves written by a core are uploaded as they change, and saves from your other
devices come back down, so a game you leave on the MiSTer picks up where you
left off on a handheld or an emulator.

Part of [1Retro](https://1retro.com). You need a 1Retro account, and the MiSTer
is linked to it once from the Scripts menu.

## Install with Update All (recommended)

This is the one that keeps itself up to date: every `update_all` run from then
on installs the current version.

1. Download [`downloader_1retro.zip`](https://raw.githubusercontent.com/one-retro/1retro-mister/db/downloader_1retro.zip).
2. Extract it into `/media/fat` on the SD card. It contains a single small
   `downloader_1retro.ini`, which the Downloader picks up on its own. Nothing
   else needs editing.
3. Run **Update All** (or **Downloader**) from the Scripts menu.

## Install by hand

```sh
cd /media/fat/Scripts
wget https://github.com/one-retro/1retro-mister/releases/latest/download/1retro-mister
wget https://github.com/one-retro/1retro-mister/releases/latest/download/1retro-mister-sync.sh
wget https://github.com/one-retro/1retro-mister/releases/latest/download/1retro-mister-daemon.sh
chmod +x 1retro-mister 1retro-mister-sync.sh 1retro-mister-daemon.sh
```

Re-run those to upgrade. Nothing else on the MiSTer is touched.

## First run

Pick **1retro-mister-sync** from the Scripts menu. The first run shows a code
and a URL on screen: open it on your phone or desktop to link the MiSTer to your
account. After that it syncs and drops back to the menu.

Everything the tool stores lives in `/media/fat/1retro`, and nothing removes it,
including an upgrade.

## Sync in the background

**1retro-mister-daemon** from the Scripts menu starts a background sync that
watches for save changes. From a shell it also takes `start`, `stop`, `restart`
and `status`:

```sh
/media/fat/Scripts/1retro-mister-daemon.sh status
```

Logs land in `/media/fat/1retro/daemon.log`, one generation of rotation. To
start it at boot, append this to `/media/fat/linux/user-startup.sh`:

```sh
/media/fat/Scripts/1retro-mister-daemon.sh start
```

## What is in this repo

| Path                     | What it is                                                     |
| ------------------------ | -------------------------------------------------------------- |
| `scripts/`               | The two Scripts-menu wrappers, attached to every release        |
| `generate_db.py`         | Builds the Downloader database from a published release         |
| `.github/workflows/db.yml` | Runs the generator when a release is published                |
| `db` branch              | The generated `db.json.zip` and `downloader_1retro.zip`         |

The `1retro-mister` binary is built from the 1Retro source tree (armv7 musl,
static) and attached to each release here. The database is:

- id: `1retro`
- url: `https://raw.githubusercontent.com/one-retro/1retro-mister/db/db.json.zip`

Both are fixed permanently. Downloader tracks installed files by database id, so
changing either would duplicate files on every SD card and break cleanup.

## Support

Issues and questions: [1retro.com](https://1retro.com) or the
[Discord](https://discord.gg/vYKSvqVkdE).
