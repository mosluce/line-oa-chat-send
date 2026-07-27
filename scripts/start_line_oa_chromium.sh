#!/usr/bin/env bash
# Start exactly one headed Chromium with a private persistent profile and loopback CDP.
# This script never logs in to LINE; it creates only the selected profile directory when absent and runs Chromium in the foreground.
set -euo pipefail

profile_dir="${LINE_OA_SEND_CHAT_CHROMIUM_PROFILE:-/opt/data/chromium}"
profile_dir_source="LINE_OA_SEND_CHAT_CHROMIUM_PROFILE (or fallback /opt/data/chromium)"
chromium_bin="${LINE_OA_CHROMIUM:-}"
cdp_port="9222"
display="${DISPLAY:-}"

usage() {
  cat <<'EOF'
Usage: start_line_oa_chromium.sh [options]

Start a headed Chromium with a persistent profile and loopback-only CDP.
The profile comes from LINE_OA_SEND_CHAT_CHROMIUM_PROFILE, falling back to
/opt/data/chromium. The directory is created with mode 700 when absent.

Options:
  --profile-dir DIR       Override the environment-selected profile directory
  --chromium PATH         Chromium executable (or set LINE_OA_CHROMIUM)
  --cdp-port PORT         Loopback CDP port (default: 9222)
  --display DISPLAY       Headed X display (default: $DISPLAY)
  -h, --help              Show this help

The process remains in the foreground; use a supervisor or a tracked background process.
EOF
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile-dir) profile_dir="${2:-}"; profile_dir_source="--profile-dir"; shift 2 ;;
    --chromium) chromium_bin="${2:-}"; shift 2 ;;
    --cdp-port) cdp_port="${2:-}"; shift 2 ;;
    --display) display="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$profile_dir" ]] || die "profile directory is empty; set LINE_OA_SEND_CHAT_CHROMIUM_PROFILE or pass --profile-dir."
if [[ ! -e "$profile_dir" ]]; then
  umask 077
  mkdir -p -- "$profile_dir"
  chmod 700 -- "$profile_dir"
  printf 'Created private Chromium profile directory from %s: %s\n' "$profile_dir_source" "$profile_dir"
fi
[[ -d "$profile_dir" && -r "$profile_dir" && -w "$profile_dir" ]] || die "profile path must be a readable/writable directory: $profile_dir"
[[ "$cdp_port" =~ ^[0-9]{1,5}$ ]] && (( cdp_port > 0 && cdp_port < 65536 )) || die "--cdp-port must be 1-65535"
xvfb_pid=""
if [[ -z "$display" ]]; then
  command -v Xvfb >/dev/null 2>&1 || die "a headed display is required and Xvfb is unavailable. Install Xvfb or pass --display / set DISPLAY."
  display="${LINE_OA_SEND_CHAT_XVFB_DISPLAY:-:99}"
  Xvfb "$display" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
  xvfb_pid="$!"
  trap 'kill "$xvfb_pid" 2>/dev/null || true' EXIT INT TERM
  sleep 0.2
  kill -0 "$xvfb_pid" 2>/dev/null || die "could not start private Xvfb display $display; choose LINE_OA_SEND_CHAT_XVFB_DISPLAY or provide DISPLAY."
  printf 'Started private Xvfb display %s for this Chromium session.\n' "$display"
fi

if curl --max-time 2 -fsS "http://127.0.0.1:${cdp_port}/json/version" >/dev/null 2>&1; then
  die "CDP is already reachable on 127.0.0.1:${cdp_port}; reuse it instead of starting another Chromium."
fi

if [[ -z "$chromium_bin" ]]; then
  for candidate in chromium chromium-browser google-chrome google-chrome-stable; do
    if command -v "$candidate" >/dev/null 2>&1; then
      chromium_bin="$(command -v "$candidate")"
      break
    fi
  done
fi
if [[ -z "$chromium_bin" && -n "${LINE_OA_SEND_CHAT_BROWSER_DIR:-}" && -d "$LINE_OA_SEND_CHAT_BROWSER_DIR" ]]; then
  chromium_bin="$(find "$LINE_OA_SEND_CHAT_BROWSER_DIR" -type f -path '*/chrome-linux*/chrome' -perm -u+x -print -quit 2>/dev/null || true)"
fi
[[ -n "$chromium_bin" && -x "$chromium_bin" ]] || die "Chromium was not found. Set LINE_OA_CHROMIUM, install a system Chromium, or run scripts/setup_line_oa_runtime.sh and export LINE_OA_SEND_CHAT_BROWSER_DIR."

printf 'Starting headed Chromium with loopback CDP on 127.0.0.1:%s.\n' "$cdp_port"
if [[ -n "$xvfb_pid" ]]; then
  trap 'kill "$xvfb_pid" 2>/dev/null || true' EXIT INT TERM
  env DISPLAY="$display" "$chromium_bin" \
    --remote-debugging-address=127.0.0.1 \
    --remote-debugging-port="$cdp_port" \
    --remote-allow-origins='*' \
    --user-data-dir="$profile_dir" \
    --no-first-run \
    --no-default-browser-check \
    https://chat.line.biz/ &
  chromium_pid="$!"
  wait "$chromium_pid"
  exit $?
fi
exec env DISPLAY="$display" "$chromium_bin" \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port="$cdp_port" \
  --remote-allow-origins='*' \
  --user-data-dir="$profile_dir" \
  --no-first-run \
  --no-default-browser-check \
  https://chat.line.biz/
