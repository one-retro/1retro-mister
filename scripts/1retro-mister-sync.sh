#!/bin/sh
#
# 1retro-mister-sync.sh — run a single 1retro save sync and return.
#
# This is the MiSTer Scripts-menu entry point for a one-shot sync: it makes
# sure the device is logged in (running the interactive device-auth flow on
# the MiSTer screen the first time), syncs your saves with the cloud once,
# and then drops back to the menu. Use this if you'd rather sync by hand
# than leave the background daemon (1retro-mister-daemon.sh) running.
#
# Any extra arguments are passed straight through to `1retro-mister sync`,
# for example:
#
#   ./1retro-mister-sync.sh --dry-run
#
# Configuration (override in the environment or by editing the constants below):
#   BIN          path to the 1retro-mister binary
#   STATE_DIR    state directory (default /media/fat/1retro)

set -u

BIN="${BIN:-/media/fat/Scripts/1retro-mister}"
STATE_DIR="${STATE_DIR:-/media/fat/1retro}"

PID_FILE="$STATE_DIR/daemon.pid"

# True when the background daemon (1retro-mister-daemon.sh) is running. It owns
# the state DB exclusively, so a manual sync can't run alongside it — and isn't
# needed, since the daemon already syncs. Mirrors is_running() in the daemon
# script so we can bail early with a friendly message.
daemon_running() {
    [ -f "$PID_FILE" ] || return 1
    pid=$(cat "$PID_FILE" 2>/dev/null) || return 1
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null
}

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

if daemon_running; then
    echo "The 1retro background daemon is running and already syncing your saves."
    echo "Stop it with 1retro-mister-daemon.sh stop to run a one-shot sync by hand."
    exit 0
fi

mkdir -p "$STATE_DIR" || {
    echo "error: cannot create state dir: $STATE_DIR" >&2
    exit 1
}

# Make sure we're logged in first. `login --check` never prompts; if it fails
# we run the interactive device-auth flow on screen.
if ! "$BIN" --state-dir "$STATE_DIR" login --check >/dev/null 2>&1; then
    echo "Not logged in — starting device authorization."
    echo "Follow the on-screen instructions to log in from another device."
    echo
    if ! "$BIN" --state-dir "$STATE_DIR" login; then
        echo "error: login did not complete; sync not run." >&2
        exit 1
    fi
    echo
fi

echo "Syncing 1retro saves..."
"$BIN" --state-dir "$STATE_DIR" sync "$@"
status=$?

if [ "$status" -eq 0 ]; then
    echo "Sync complete."
else
    echo "Sync failed (exit $status)." >&2
fi
exit "$status"
