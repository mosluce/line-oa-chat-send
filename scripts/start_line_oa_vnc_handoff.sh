#!/usr/bin/env bash
# Start a temporary, loopback-only VNC/noVNC handoff and Cloudflare Quick Tunnel.
# The emitted URL is a short-lived bearer secret: share only with the intended user.
set -euo pipefail

runtime_dir="${LINE_OA_SEND_CHAT_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/line-oa-chat-send}"
profile_dir="${LINE_OA_SEND_CHAT_CHROMIUM_PROFILE:-/opt/data/chromium}"
display="${LINE_OA_SEND_CHAT_XVFB_DISPLAY:-:99}"
for command in Xvfb x11vnc websockify caddy cloudflared; do
  command -v "$command" >/dev/null 2>&1 || { printf 'ERROR: missing %s; install the protected-handoff host dependencies first.\n' "$command" >&2; exit 2; }
done
novnc_root=""
for candidate in /usr/share/novnc /usr/share/noVNC; do [[ -d "$candidate" ]] && { novnc_root="$candidate"; break; }; done
[[ -n "$novnc_root" ]] || { printf 'ERROR: noVNC web assets were not found.\n' >&2; exit 2; }

mkdir -p "$runtime_dir/handoff"
chmod 700 "$runtime_dir" "$runtime_dir/handoff"
token="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
config="$runtime_dir/handoff/Caddyfile"
printf '{ auto_https off }\nhttp://127.0.0.1:6081 {\n  @private path /%s/*\n  handle @private { uri strip_prefix /%s; reverse_proxy 127.0.0.1:6080 }\n  respond 404\n}\n' "$token" "$token" > "$config"
chmod 600 "$config"

cleanup() { kill "${tunnel_pid:-}" "${caddy_pid:-}" "${websockify_pid:-}" "${vnc_pid:-}" "${chrome_pid:-}" "${xvfb_pid:-}" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
Xvfb "$display" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 & xvfb_pid=$!
sleep .2; kill -0 "$xvfb_pid" 2>/dev/null || { printf 'ERROR: Xvfb failed.\n' >&2; exit 2; }
DISPLAY="$display" LINE_OA_SEND_CHAT_CHROMIUM_PROFILE="$profile_dir" bash "$(dirname "$0")/start_line_oa_chromium.sh" & chrome_pid=$!
x11vnc -display "$display" -localhost -nopw -forever -shared -rfbport 5900 >/dev/null 2>&1 & vnc_pid=$!
websockify --web "$novnc_root" 127.0.0.1:6080 127.0.0.1:5900 >/dev/null 2>&1 & websockify_pid=$!
caddy run --config "$config" --adapter caddyfile >/dev/null 2>&1 & caddy_pid=$!
log="$runtime_dir/handoff/cloudflared.log"
cloudflared tunnel --no-autoupdate --url http://127.0.0.1:6081 >"$log" 2>&1 & tunnel_pid=$!
for _ in $(seq 1 30); do url="$(grep -Eo 'https://[-a-z0-9]+\.trycloudflare\.com' "$log" | head -1 || true)"; [[ -n "$url" ]] && break; sleep 1; done
[[ -n "${url:-}" ]] || { printf 'ERROR: cloudflared did not provide a Quick Tunnel URL.\n' >&2; exit 2; }
printf 'HANDOFF URL (short-lived bearer secret): %s/%s/vnc.html?autoconnect=true&path=%s/websockify\n' "$url" "$token" "$token"
printf 'Keep this process running until the user reports login complete; Ctrl-C revokes the tunnel and closes Chromium.\n'
wait "$chrome_pid"
