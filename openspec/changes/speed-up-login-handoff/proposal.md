## Why

Requesting a LINE login handoff currently takes an unacceptably long wall-clock time from the moment the user asks for it until they can actually operate the login screen, and we do not know which phase is responsible. The current script also couples the handoff to the Chromium lifecycle, which makes the handoff refuse to start while the sending browser is running, and kills the freshly authenticated browser when the handoff is revoked — forcing a second cold start before any message can be sent.

## What Changes

- Add phase timing instrumentation to the handoff so every startup phase (display readiness, Chromium/CDP readiness, VNC stack listening, tunnel URL emission, public reachability) is recorded and reported. This stays in the script permanently as an operational diagnostic, not as a throwaway spike.
- **BREAKING** Split the browser session from the handoff. Chromium and its X display become a long-lived unit owned by the session scripts; the handoff attaches to the existing display instead of starting its own Chromium.
  - The handoff no longer refuses to start when Chromium is already running.
  - Revoking the handoff no longer terminates Chromium or the display.
  - Re-authentication mid-session no longer requires shutting the browser down first.
- Move public-URL verification into the handoff script. The script waits until the public URL returns HTTP 200 containing `noVNC`, and only then prints the URL; otherwise it exits non-zero. This removes the agent round-trips that the skill instructions currently require.
- Replace the fixed `sleep .2` Xvfb wait with an actual readiness poll on the X socket.
- Tighten the cloudflared URL discovery poll from 1s granularity to 200ms.
- Collapse the two `pick_loopback_port` Python invocations into one.
- Select the Caddy listener port dynamically instead of hard-coding `:6081`, and stop discarding Caddy's output so a bind failure is reported instead of surfacing as a blank page.
- Keep the loopback-only VNC stack (x11vnc, websockify, Caddy) alive with the browser session; only the Cloudflare Quick Tunnel remains ephemeral and per-handoff.

Explicitly out of scope: a persistent or named Cloudflare tunnel. The tunnel stays ephemeral per handoff, so its registration cost remains on the critical path by design.

## Capabilities

### New Capabilities
- `browser-session`: lifecycle of the long-lived headed Chromium, its private X display, its loopback-only screen-sharing stack, and its loopback CDP endpoint — start, readiness, and graceful shutdown, independent of any handoff.
- `login-handoff`: arming, verifying, timing, and revoking a temporary externally reachable interactive login session that attaches to an existing browser session.

### Modified Capabilities
<!-- No existing specs in openspec/specs/ yet; both capabilities above are new. -->

## Impact

- `scripts/start_line_oa_vnc_handoff.sh` — largest change: drops Chromium ownership, attaches to an existing display, adds verification, timing, and dynamic Caddy port.
- `scripts/start_line_oa_chromium.sh` — takes ownership of a durable, discoverable display rather than a private Xvfb trapped to its own lifetime.
- New shutdown path for the browser session, currently only described in prose in `SKILL.md`.
- `SKILL.md` — the handoff and shutdown instructions become obsolete once verification moves into the script. Rewriting them is handled by the separate `trim-skill-docs` change; this change must not leave the two inconsistent.
- No change to `send_line_oa_chat.py`, `run_line_oa_chat.sh`, or `setup_line_oa_runtime.sh`.
- No change to the network exposure model: VNC, websockify, Caddy, and CDP remain loopback-only, and nothing is externally reachable until cloudflared runs.
