#!/usr/bin/env bash
# Start exactly one headed Chromium with a private persistent profile and loopback CDP.
# This script never logs in to LINE, never creates a profile, and runs Chromium in the foreground.
set -euo pipefail

profile_dir=""
chromium_bin="${LINE_OA_CHROMIUM:-}"
cdp_port="9222"
display="${DISPLAY:-}"

usage() {
  cat <<'EOF'
Usage: start_line_oa_chromium.sh --profile-dir DIR [options]

Start a headed Chromium with a pre-existing private profile and loopback-only CDP.

Required:
  --profile-dir DIR       Existing private persistent Chromium profile directory

Options:
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
    --profile-dir) profile_dir="${2:-}"; shift 2 ;;
    --chromium) chromium_bin="${2:-}"; shift 2 ;;
    --cdp-port) cdp_port="${2:-}"; shift 2 ;;
    --display) display="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$profile_dir" ]] || die "--profile-dir is required; do not create a new profile for an existing LINE session."
[[ -d "$profile_dir" && -r "$profile_dir" && -w "$profile_dir" ]] || die "profile directory must already exist and be readable/writable: $profile_dir"
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
