#!/bin/sh
#
# 1retro.sh — the 1Retro entry in the MiSTer Scripts menu.
#
# Run with no arguments (which is what the Scripts menu does) it opens the
# on-screen menu: sync now, watch for saves in the background, start watching at
# boot, sign out. It is navigated with the controller (up and down to move, A to
# select, B to leave), so none of those settings need SSH or taking the card out
# of the machine.
#
#   ./1retro.sh           # the menu
#   ./1retro.sh watch     # the background watcher, logging to the state dir
#
# The `watch` form is what the "Start watching at boot" option runs from
# user-startup.sh. Anything else you might want is on the binary itself
# (`1retro-mister --help`), which is beside this script.
#
# Configuration (override in the environment or by editing the constants below):
#   BIN          path to the 1retro-mister binary
#   STATE_DIR    state directory (default /media/fat/1retro)

set -u

BIN="${BIN:-/media/fat/Scripts/1retro-mister}"
STATE_DIR="${STATE_DIR:-/media/fat/1retro}"

# The binary has to be executable, and none of the ways it arrives sets that
# bit: the Downloader (update_all) never chmods what it installs, and a plain
# wget doesn't either. Both are one chmod away from working, so fix it here
# rather than making it the user's problem. On exfat the chmod is a no-op and
# the mount options have already decided, hence the final re-test.
ensure_bin() {
    [ -f "$BIN" ] || return 1
    [ -x "$BIN" ] || chmod +x "$BIN" 2>/dev/null || true
    [ -x "$BIN" ]
}

if ! ensure_bin; then
    echo "error: 1retro-mister not found or not executable: $BIN" >&2
    echo "       set BIN=/path/to/1retro-mister or copy the binary in place" >&2
    exit 1
fi

mkdir -p "$STATE_DIR" || {
    echo "error: cannot create state dir: $STATE_DIR" >&2
    exit 1
}

case "${1:-}" in
    watch)
        # Started at boot, where nobody is watching the console, so everything
        # goes to the log. Truncated per boot rather than appended, so it cannot
        # grow without bound on a machine that is rarely turned off.
        exec "$BIN" --state-dir "$STATE_DIR" watch >"$STATE_DIR/daemon.log" 2>&1
        ;;
    "")
        # The menu pauses a running background sync while it is open and starts
        # it again on the way out, because both want the same state database.
        exec "$BIN" --state-dir "$STATE_DIR" menu
        ;;
    *)
        echo "Usage: $0 [watch]" >&2
        exit 2
        ;;
esac
