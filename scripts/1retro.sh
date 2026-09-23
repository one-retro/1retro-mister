#!/bin/sh
#
# 1retro.sh — the 1Retro entry in the MiSTer Scripts menu.
#
# Opens the on-screen menu: sync now, watch for saves in the background, start
# watching at boot, sign out. It is navigated with the controller (up and down
# to move, A to select, B to leave), so none of these settings need SSH or
# taking the card out of the machine.
#
# The other two scripts here do one thing each without asking, which is what
# you want over ssh or from another script. This one is the place to look
# when you are standing in front of the machine.
#
# Configuration (override in the environment or by editing the constants below):
#   BIN          path to the 1retro-mister binary
#   STATE_DIR    state directory (default /media/fat/1retro)

set -u

BIN="${BIN:-/media/fat/Scripts/1retro-mister}"
STATE_DIR="${STATE_DIR:-/media/fat/1retro}"

# The binary has to be executable, and neither of the two ways it arrives sets
# that bit: the Downloader (update_all) never chmods what it installs, and a
# plain wget doesn't either. Both are one chmod away from working, so fix it
# here rather than making it the user's problem. On exfat the chmod is a no-op
# and the mount options have already decided, hence the final re-test.
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

# The menu pauses a running background sync while it is open and starts it
# again on the way out, because both want the same state database.
exec "$BIN" --state-dir "$STATE_DIR" menu
