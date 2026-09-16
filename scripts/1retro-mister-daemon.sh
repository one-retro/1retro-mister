#!/bin/sh
#
# 1retro-mister-daemon.sh — start/stop the 1retro-mister sync as a background
# service on a MiSTer FPGA.
#
# Usage:
#   ./1retro-mister-daemon.sh             # log in if needed, then start daemon
#   ./1retro-mister-daemon.sh start       # start watch in the background
#   ./1retro-mister-daemon.sh stop        # stop the running daemon
#   ./1retro-mister-daemon.sh restart     # stop + start
#   ./1retro-mister-daemon.sh status      # is it running?
#
# Running with no arguments is the MiSTer Scripts-menu entry point: it
# checks for a stored login, runs the interactive device-auth flow if
# needed, and then starts the background sync daemon.
#
# To start automatically at boot, append the following to
# /media/fat/linux/user-startup.sh:
#
#   /media/fat/Scripts/1retro-mister-daemon.sh start
#
# Configuration (override in the environment or by editing the constants below):
#   BIN          path to the 1retro-mister binary
#   STATE_DIR    state + log directory (default /media/fat/1retro)
#   INTERVAL     poll interval in seconds (default: the binary's own, which
#                is 300 when it can watch the filesystem and 30 when it can't)

set -u

BIN="${BIN:-/media/fat/Scripts/1retro-mister}"
STATE_DIR="${STATE_DIR:-/media/fat/1retro}"
# Left empty on purpose: passing a number here would override the binary's
# choice, which already depends on whether its filesystem watcher armed.
INTERVAL="${INTERVAL:-}"

PID_FILE="$STATE_DIR/daemon.pid"
LOG_FILE="$STATE_DIR/daemon.log"

ensure_dirs() {
    mkdir -p "$STATE_DIR" || {
        echo "error: cannot create state dir: $STATE_DIR" >&2
        exit 1
    }
}

is_running() {
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

bin_or_die() {
    ensure_bin && return 0
    echo "error: 1retro-mister not found or not executable: $BIN" >&2
    echo "       set BIN=/path/to/1retro-mister or copy the binary in place" >&2
    exit 1
}

cmd_start() {
    bin_or_die

    ensure_dirs

    if is_running; then
        echo "1retro-mister daemon already running (pid $(cat "$PID_FILE"))"
        return 0
    fi

    # Verify the device is logged in before backgrounding — `login --check`
    # never prompts, so it's safe to run unattended.
    if ! "$BIN" --state-dir "$STATE_DIR" login --check >/dev/null 2>&1; then
        echo "error: not logged in. Run: $BIN login" >&2
        exit 1
    fi

    # Rotate the previous log so we keep one generation around.
    [ -f "$LOG_FILE" ] && mv -f "$LOG_FILE" "$LOG_FILE.old"

    # Detach: nohup keeps it alive past this shell, redirect stdio to log.
    if [ -n "$INTERVAL" ]; then
        set -- --interval "$INTERVAL"
    else
        set --
    fi
    nohup "$BIN" --state-dir "$STATE_DIR" \
        watch "$@" \
        >>"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"
    echo "1retro-mister daemon started (pid $(cat "$PID_FILE"))"
    echo "logs: $LOG_FILE"
}

cmd_stop() {
    if ! is_running; then
        echo "1retro-mister daemon not running"
        rm -f "$PID_FILE"
        return 0
    fi
    pid=$(cat "$PID_FILE")
    kill "$pid" 2>/dev/null || true

    # Give it a few seconds to exit cleanly, then force.
    i=0
    while kill -0 "$pid" 2>/dev/null && [ $i -lt 10 ]; do
        sleep 1
        i=$((i + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
    echo "1retro-mister daemon stopped"
}

cmd_status() {
    if is_running; then
        echo "1retro-mister daemon running (pid $(cat "$PID_FILE"))"
        return 0
    fi
    echo "1retro-mister daemon not running"
    return 3
}

# Default entry point invoked when the script is run with no arguments
# (e.g. picked from the MiSTer Scripts menu): make sure the device is
# logged in — running the interactive device-auth flow on the MiSTer
# screen if it isn't — and then start the background daemon.
cmd_default() {
    bin_or_die

    ensure_dirs

    if ! "$BIN" --state-dir "$STATE_DIR" login --check >/dev/null 2>&1; then
        echo "Not logged in — starting device authorization."
        echo "Follow the on-screen instructions to log in from another device."
        echo
        if ! "$BIN" --state-dir "$STATE_DIR" login; then
            echo "error: login did not complete; daemon not started." >&2
            exit 1
        fi
        echo
    fi

    cmd_start
}

case "${1:-}" in
    "")      cmd_default ;;
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    restart) cmd_stop; cmd_start ;;
    status)  cmd_status ;;
    *)
        echo "Usage: $0 [start|stop|restart|status]" >&2
        exit 2
        ;;
esac
