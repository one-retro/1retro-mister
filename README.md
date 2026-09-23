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

Over SSH, the whole install is one line:

```sh
wget -O /media/fat/downloader_1retro.ini \
  https://raw.githubusercontent.com/one-retro/1retro-mister/db/downloader_1retro.ini
```

Or save [`downloader_1retro.ini`](https://raw.githubusercontent.com/one-retro/1retro-mister/db/downloader_1retro.ini)
onto the card as `/media/fat/downloader_1retro.ini` from a desktop.

Then run **Update All** (or **Downloader**) from the Scripts menu. Downloader
reads every `/media/fat/downloader_*.ini` on each run, so nothing else needs
editing, and 1Retro is installed and upgraded along with everything else from
then on.

## Install by hand

```sh
cd /media/fat/Scripts
wget https://github.com/one-retro/1retro-mister/releases/latest/download/1retro-mister
wget https://github.com/one-retro/1retro-mister/releases/latest/download/1retro.sh
chmod +x 1retro-mister 1retro.sh
```

Re-run those to upgrade. Nothing else on the MiSTer is touched.

## First run

Pick **1retro** from the Scripts menu. The first run shows a code and a URL on
screen: open it on your phone or desktop to link the MiSTer to your account.

Everything the tool stores lives in `/media/fat/1retro`, and nothing removes it,
including an upgrade.

## The menu

**1retro** from the Scripts menu is where everything lives. Move with up and
down on the controller, A to select, B to leave. No keyboard, no SSH, and
nothing to edit on the card:

- **Sync saves**: upload what changed here, download what changed elsewhere.
- **Watch for saves**: keep syncing in the background after you leave. Saves go
  up as a core writes them, and anything saved on another device comes down.
- **Start watching at boot**: start that again after a restart. It adds one
  guarded line to `/media/fat/linux/user-startup.sh` and takes it back out when
  you turn the option off, leaving every other line in that file alone.
- **Sign out**: forget the login on this device.

Underneath, it shows the account this MiSTer is signed in as, when it last
synced, and how many saves it is tracking.

Opening the menu pauses a running background sync and starts it again on the way
out, because both want the same state database.

## From a shell

The binary sits next to the script and does the same jobs without the menu,
which is what you want over SSH or from another script:

```sh
/media/fat/Scripts/1retro-mister sync     # sync once and exit
/media/fat/Scripts/1retro-mister watch    # keep syncing in the foreground
/media/fat/Scripts/1retro-mister --help
```

Background logs land in `/media/fat/1retro/daemon.log`, rewritten each time the
watcher starts so it cannot grow without bound.

## What is in this repo

| Path                     | What it is                                                     |
| ------------------------ | -------------------------------------------------------------- |
| `scripts/1retro.sh`      | The one Scripts-menu entry, attached to every release            |
| `generate_db.py`         | Builds the Downloader database from a published release         |
| `.github/workflows/db.yml` | Runs the generator when a release is published                |
| `db` branch              | The generated `db.json.zip` and `downloader_1retro.ini`         |

The `1retro-mister` binary is built from the 1Retro source tree (armv7 musl,
static) and attached to each release here. The database is:

- id: `1retro`
- url: `https://raw.githubusercontent.com/one-retro/1retro-mister/db/db.json.zip`

Both are fixed permanently. Downloader tracks installed files by database id, so
changing either would duplicate files on every SD card and break cleanup.

## License

The contents of this repository are [MIT](LICENSE) licensed. The
`1retro-mister` binary attached to releases is not open source, and is
distributed for use with a 1Retro account.

## Support

Issues and questions: [1retro.com](https://1retro.com) or the
[Discord](https://discord.gg/vYKSvqVkdE).
