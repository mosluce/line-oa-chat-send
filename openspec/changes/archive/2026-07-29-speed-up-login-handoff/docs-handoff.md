# Handoff to `trim-skill-docs`

What this change invalidated, and what replaced it. `trim-skill-docs` should
document the sequence below rather than re-deriving it.

## Statements in `SKILL.md` that are now wrong

| Location | Statement | Why it is wrong now |
| --- | --- | --- |
| Authentication and session setup, step 2 | The handoff "starts headed Chromium, loopback-only VNC/noVNC, a high-entropy private Caddy path, and a temporary Cloudflare Quick Tunnel" | The handoff no longer starts Chromium or the display. It attaches to a running session and starts only the tunnel and the private route. |
| Authentication and session setup, step 2 | "Before sharing it, verify the public URL returns a non-empty HTTP 200 page containing `noVNC`; when available, confirm the title is `noVNC`… If either check fails, revoke the process, correct the local Caddy/noVNC route, and generate a fresh URL." | Verification is inside the script. It prints a URL only after HTTP 200 with noVNC content, and on failure revokes what it started and exits non-zero naming the failing phase. The whole paragraph goes. |
| Authentication and session setup, step 2 | "Before launching, ensure `LINE_OA_SEND_CHAT_XVFB_DISPLAY` is unused; if the default `:99` is already active, select another private local display" | The session script checks this itself and refuses with a named error. |
| Starting Chromium and CDP, step 3 | "The process remains in the foreground; use a supervisor or a tracked background process." | The session now runs in the background and is recorded in a state file. |
| Shutdown after use, all 5 steps | Prose procedure: identify the root process, avoid `pkill`, send SIGTERM, verify CDP unreachable, do not force kill | All of it is `scripts/stop_line_oa_chromium.sh`. Reduce to the command plus what a non-zero exit means. |
| Environment preflight, step 3 | "`scripts/start_line_oa_chromium.sh` … if `DISPLAY` is missing, starts a private local `Xvfb` display **for the lifetime of its Chromium child**" | The display now outlives any single Chromium invocation and is owned by the session. |
| Pitfalls | "Never assume VNC `5900` or websockify `6080` are free" | Now enforced in code: all four ports are selected dynamically in one call. Move the reasoning to `references/handoff-operations.md`. |
| Pitfalls | "A local `curl` success is insufficient for a Cloudflare Quick Tunnel: verify the bearer URL from outside" | Still true, but enforced by the script. Reasoning moves to references. |
| Pitfalls | "If the tunnel page is empty, check that Caddy uses a host-agnostic site address… Keep multi-line Caddy `handle` blocks structurally formatted" | Encoded in `scripts/lib/caddy.sh`. Reasoning moves to references. |

## Statements in `README.md` that are now wrong

- The handoff description ("creates a temporary Cloudflare noVNC URL") should say it attaches to a running session, and that revoking leaves the session running.
- "If CDP is unavailable, start one headed Chromium with a private profile and loopback-only CDP endpoint" — the command is now `scripts/start_line_oa_chromium.sh`, which also starts the loopback screen-sharing stack.
- No shutdown command is documented at all; there is now one.

## New operator sequence

```bash
# 1. Start the browser session. Owns the display, Chromium, and a loopback-only
#    screen-sharing stack. Nothing is externally reachable.
bash scripts/start_line_oa_chromium.sh

# 2. Only when the user asks to log in or re-authenticate: arm a handoff.
#    Prints one URL, already verified reachable. Fails non-zero otherwise.
export LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login
export LINE_OA_SEND_CHAT_HANDOFF_TTL_SECONDS=900   # 60-3600, default 900
bash scripts/start_line_oa_vnc_handoff.sh

# 3. Revoke as soon as login is done. Leaves the session running.
bash scripts/stop_line_oa_vnc_handoff.sh

# 4. Send. Unchanged.
bash scripts/run_line_oa_chat.sh --recipient "<name>" --message "<text>" [--send]

# 5. Stop the session when the work is finished.
bash scripts/stop_line_oa_chromium.sh
```

## Script inventory

| Script | Role |
| --- | --- |
| `scripts/start_line_oa_chromium.sh` | Start the browser session; owns display, Chromium, loopback VNC stack; writes session state |
| `scripts/stop_line_oa_chromium.sh` | Stop the session; revokes any armed handoff first; leaves the profile untouched |
| `scripts/start_line_oa_vnc_handoff.sh` | Arm and verify a login handoff on a running session |
| `scripts/stop_line_oa_vnc_handoff.sh` | Revoke the handoff; session keeps running |
| `scripts/run_line_oa_chat.sh` | Send CLI launcher (unchanged) |
| `scripts/send_line_oa_chat.py` | Send implementation (unchanged) |
| `scripts/setup_line_oa_runtime.sh` | Provision the Python runtime (unchanged) |
| `scripts/lib/session.sh` | Session state: write, read, liveness |
| `scripts/lib/caddy.sh` | Front end: closed (404) vs armed (token route) |
| `scripts/lib/ports.sh` | Loopback port selection and readiness polling |
| `scripts/lib/phase_timing.sh` | Phase timing on every run |

## Points the docs should still make

- **The security boundary is unchanged in substance.** The handoff still grants
  interactive control of the browser to whoever holds the URL, is still
  login-only by policy rather than by mechanism, and must still be revoked
  promptly. Attach mode narrows the blast radius of a *revocation* (the session
  survives), not of the handoff itself.
- **Nothing is externally reachable between handoffs.** The loopback stack runs
  with the session; only the tunnel is ephemeral. The front end answers 404
  until a token route is armed.
- **Refusals worth documenting as decision rules:** no session, stale session
  state, missing login purpose, out-of-range TTL, and a handoff already armed.
- **A profile locked by another hostname is reported distinctly** and is not
  cleared automatically, because the other Chromium may genuinely still hold it.

## What is still unmeasured

Tasks 1.5–1.7 and 6.8 are target-host only and not yet run. Until then the docs
should not claim a speedup figure. The phase-timing log is the source for that
number when it exists.
