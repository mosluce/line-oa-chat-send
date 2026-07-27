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
[[ -n "$display" ]] || die "a headed display is required; pass --display or set DISPLAY."

if curl --max-time 2 -fsS "http://127.0.0.1:${cdp_port}/json/version" >/dev/null; then
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
[[ -n "$chromium_bin" && -x "$chromium_bin" ]] || die "Chromium was not found. Pass --chromium PATH or set LINE_OA_CHROMIUM to an executable."

printf 'Starting headed Chromium with loopback CDP on 127.0.0.1:%s.\n' "$cdp_port"
exec env DISPLAY="$display" "$chromium_bin" \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port="$cdp_port" \
  --remote-allow-origins='*' \
  --user-data-dir="$profile_dir" \
  --no-first-run \
  --no-default-browser-check \
  https://chat.line.biz/
