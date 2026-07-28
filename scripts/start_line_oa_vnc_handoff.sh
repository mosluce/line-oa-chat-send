#!/usr/bin/env bash
# Arm a temporary, externally reachable login handoff on an existing browser
# session.
#
# This attaches to a running session. It does not start, own, or terminate
# Chromium or its display, and revoking it leaves the session running.
#
# The emitted URL is a short-lived bearer secret: whoever holds it gets
# interactive control of the browser. Share it only with the intended user in a
# direct private channel, and revoke it as soon as login is done.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/session.sh
source "$script_dir/lib/session.sh"
# shellcheck source=lib/caddy.sh
source "$script_dir/lib/caddy.sh"
# shellcheck source=lib/phase_timing.sh
source "$script_dir/lib/phase_timing.sh"

handoff_purpose="${LINE_OA_SEND_CHAT_HANDOFF_PURPOSE:-}"
handoff_ttl_seconds="${LINE_OA_SEND_CHAT_HANDOFF_TTL_SECONDS:-900}"
verify_timeout="${LINE_OA_SEND_CHAT_HANDOFF_VERIFY_TIMEOUT:-90}"
url_timeout="${LINE_OA_SEND_CHAT_HANDOFF_URL_TIMEOUT:-60}"

phase_init handoff
phase_mark script_entry

# Named so a failure reports the phase it died in rather than a bare exit code.
fail_phase() {
  local phase="$1"; shift
  printf 'ERROR [%s]: %s\n' "$phase" "$*" >&2
  phase_mark "FAILED_${phase}"
  phase_summary
  bash "$script_dir/stop_line_oa_vnc_handoff.sh" --quiet >/dev/null 2>&1 || true
  exit 2
}

# This process grants interactive control of an authenticated browser. It is
# deliberately limited to a user-operated LINE login/reauthentication handoff.
[[ "$handoff_purpose" == "line-login" ]] || {
  printf 'ERROR: set LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login to start an interactive handoff.\n' >&2
  exit 2
}
[[ "$handoff_ttl_seconds" =~ ^[0-9]+$ ]] && (( handoff_ttl_seconds >= 60 && handoff_ttl_seconds <= 3600 )) || {
  printf 'ERROR: LINE_OA_SEND_CHAT_HANDOFF_TTL_SECONDS must be an integer from 60 to 3600.\n' >&2
  exit 2
}

command -v cloudflared >/dev/null 2>&1 || {
  printf 'ERROR: missing handoff dependency: cloudflared\n' >&2
  printf 'Install commands (run by an identity with host package permission; no sudo is invoked by this skill):\n' >&2
  printf '  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg -o /usr/share/keyrings/cloudflare-main.gpg\n' >&2
  printf '  printf "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main\\n" > /etc/apt/sources.list.d/cloudflared.list\n' >&2
  printf '  apt-get update && apt-get install -y cloudflared\n' >&2
  exit 2
}

# Attach, never launch. A stale state file is not a session.
session_require_live || exit 2
phase_mark session_attached

# One handoff at a time. An existing one is left intact rather than silently
# replaced, because replacing it would invalidate a URL someone may be using.
if handoff_is_armed; then
  printf 'ERROR: a handoff is already armed. Revoke it first:\n' >&2
  printf '  bash scripts/stop_line_oa_vnc_handoff.sh\n' >&2
  exit 2
fi
rm -f "$(session_handoff_path)"

caddy_config="$(session_get caddy_config)"
caddy_port="$(session_get caddy_port)"
caddy_admin_port="$(session_get caddy_admin_port)"
websockify_port="$(session_get websockify_port)"
runtime_dir="$(session_runtime_dir)"
mkdir -p "$runtime_dir/logs"

token="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
caddy_write_armed "$caddy_config" "$caddy_port" "$caddy_admin_port" "$token" "$websockify_port"
caddy_reload "$caddy_config" "$caddy_admin_port" "$runtime_dir/logs/caddy.log" \
  || fail_phase route_armed "the front end rejected the private route; see $runtime_dir/logs/caddy.log"
phase_mark route_armed

tunnel_log="$runtime_dir/logs/cloudflared.log"
: > "$tunnel_log"
chmod 600 "$tunnel_log"
cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:${caddy_port}" \
  >"$tunnel_log" 2>&1 &
tunnel_pid="$!"

# Record early so a failure below still has something to revoke.
session_write_handoff() {
  local file; file="$(session_handoff_path)"
  : > "$file"; chmod 600 "$file"
  printf 'tunnel_pid=%s\nttl_pid=%s\narmed_at=%s\nttl_seconds=%s\n' \
    "$tunnel_pid" "${ttl_pid:-}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$handoff_ttl_seconds" >> "$file"
}
session_write_handoff

# Poll at 200ms rather than 1s: at 1s granularity roughly half a second is spent
# waiting after the URL is already available.
url=""
waited=0
while :; do
  url="$(grep -Eo 'https://[-a-z0-9]+\.trycloudflare\.com' "$tunnel_log" | head -1 || true)"
  [[ -n "$url" ]] && break
  kill -0 "$tunnel_pid" 2>/dev/null || fail_phase tunnel_url "cloudflared exited before emitting a URL; see $tunnel_log"
  waited="$(awk -v w="$waited" 'BEGIN{printf "%.1f", w+0.2}')"
  awk -v w="$waited" -v d="$url_timeout" 'BEGIN{exit !(w<d)}' \
    || fail_phase tunnel_url "cloudflared did not emit a Quick Tunnel URL within ${url_timeout}s; see $tunnel_log"
  sleep 0.2
done
phase_mark tunnel_url

# Verification runs here, not in an agent turn. A local request proving the
# listener works is not enough: the tunnel is what has to be usable, so the
# public URL is fetched and its content checked. Nothing is printed until this
# passes, which makes "never share an unverified bearer URL" a property of the
# script rather than an instruction someone has to remember.
public_url="${url}/${token}/vnc.html?autoconnect=true&path=${token}/websockify"
probe_file="$(mktemp)"
trap 'rm -f "$probe_file"' EXIT
verified=0
waited=0
while :; do
  code="$(curl -s -o "$probe_file" -w '%{http_code}' --max-time 10 "$public_url" 2>/dev/null || echo 000)"
  if [[ "$code" == "200" ]] && grep -qi 'novnc' "$probe_file"; then
    verified=1
    break
  fi
  kill -0 "$tunnel_pid" 2>/dev/null || fail_phase url_verified "cloudflared exited during verification; see $tunnel_log"
  waited="$(awk -v w="$waited" 'BEGIN{printf "%.1f", w+0.5}')"
  awk -v w="$waited" -v d="$verify_timeout" 'BEGIN{exit !(w<d)}' \
    || fail_phase url_verified "the public URL did not become usable within ${verify_timeout}s (last HTTP status ${code})"
  sleep 0.5
done
(( verified )) || fail_phase url_verified "verification did not pass"
phase_mark url_verified

# TTL expiry uses the same revoke path as an explicit revocation, so there is
# one teardown, not two.
setsid bash -c '
  sleep "$1"
  bash "$2/stop_line_oa_vnc_handoff.sh" --quiet >/dev/null 2>&1 || true
' _ "$handoff_ttl_seconds" "$script_dir" >/dev/null 2>&1 &
ttl_pid="$!"
session_write_handoff
phase_mark ttl_scheduled

printf '\nHANDOFF URL (short-lived bearer secret, verified reachable):\n%s\n\n' "$public_url"
printf 'Expires in %ss. Revoke as soon as login is done:\n' "$handoff_ttl_seconds"
printf '  bash scripts/stop_line_oa_vnc_handoff.sh\n'
printf 'Revoking leaves the browser session running.\n'
phase_summary
