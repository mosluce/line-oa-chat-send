## Context

`scripts/start_line_oa_vnc_handoff.sh` starts everything a login handoff needs in one process: an Xvfb display, Chromium (via `start_line_oa_chromium.sh`), x11vnc, websockify, Caddy, and a Cloudflare Quick Tunnel. All of them are backgrounded, so the script is already parallel; the wall-clock cost is `max(Chromium cold start, tunnel registration)` plus whatever happens after the URL is printed.

Two structural consequences follow from the handoff owning Chromium:

- `start_line_oa_chromium.sh` refuses to start when CDP is already reachable. When invoked from the handoff, it exits 2, the backgrounded `chrome_pid` disappears, the final `wait "$chrome_pid"` returns immediately, and `trap cleanup` tears down the tunnel that was just established. A handoff therefore cannot be started while the sending browser is running.
- `cleanup` kills `chrome_pid` and `xvfb_pid`. Revoking a handoff destroys the browser the user just authenticated, so the first-time flow pays two Chromium cold starts.

The script also stops at printing the URL. `SKILL.md` then instructs the agent to fetch the public URL, confirm HTTP 200 with `noVNC` in the body, and on failure revoke, repair the Caddy/noVNC route, and regenerate. Each of those steps is a separate agent turn.

The measured quantity the user cares about is end-to-end wall clock from "user asks for a handoff" to "user can operate the login screen". Part of that interval lives in agent turns and is invisible to the script.

The user has ruled out a persistent or named tunnel, so per-handoff Cloudflare Quick Tunnel registration stays on the critical path.

## Goals / Non-Goals

**Goals:**

- Make it possible to attribute handoff latency to a specific phase, from a normal run, without a special debug mode.
- Remove Chromium cold start from the handoff path.
- Make handoff arm/revoke idempotent with respect to the browser session: a handoff can be armed while Chromium runs, and revoking it leaves Chromium running.
- Reduce the number of agent turns between requesting a handoff and having a shareable, verified URL to one.
- Remove fixed sleeps and fixed ports that are either slower than necessary or fail silently.

**Non-Goals:**

- A persistent or named Cloudflare tunnel, or any always-on external ingress. Explicitly rejected.
- Reducing interaction latency once connected (the `-noxdamage` full-screen polling trade-off). Separate concern; `-noxdamage` stays because it fixes the black-canvas failure.
- Changing recipient matching, message sending, or verification in `send_line_oa_chat.py`.
- Supporting non-Linux hosts. Linux remains the only target.

## Decisions

### Instrumentation is a permanent feature, not a spike

Phase timestamps are emitted on every run to a run log under the private runtime directory, and a phase summary is printed on completion. Rationale: the same question ("why was that slow?") will recur, and a permanent diagnostic answers it without re-instrumenting. It also removes the need for a separate throwaway change.

Phases recorded: script entry, display readiness, CDP reachable, LINE page present, x11vnc listening, websockify listening, Caddy listening, tunnel URL emitted, public URL verified.

The interval from tunnel URL emitted to public URL verified is the one that settles an open assumption: whether a Quick Tunnel URL is routable the moment cloudflared prints it, or whether edge propagation adds meaningful delay. The design does not depend on the answer, but the answer determines whether further work is worthwhile.

Agent-side turns and the user-observed moment the noVNC canvas becomes usable cannot be captured by the script. Those are recorded manually once, against the script's own entry timestamp, to calibrate how much of the total sits outside the script.

Alternative considered: a `--timing` flag. Rejected — the slow runs are the ones nobody thought to instrument.

### Chromium and its display become a long-lived unit; the handoff attaches

`start_line_oa_chromium.sh` owns a display that outlives any single handoff and publishes it (display number plus profile and CDP port) in a session state file under the private runtime directory. The handoff reads that state, attaches x11vnc to the existing display, and never spawns Chromium.

Consequences:

- Arming a handoff requires an existing browser session. If none exists, the handoff fails with a clear instruction to start one, rather than silently starting a second browser.
- Revoking a handoff tears down only the tunnel; the browser session is untouched.
- Re-authentication mid-session works without a shutdown.

Note on speed: because Chromium cold start currently runs in parallel with tunnel registration, removing it only shortens the first handoff if Chromium was the longer pole. This decision is justified primarily by correctness — the refuse-to-start bug and the kill-the-browser-on-revoke bug — with speed as a conditional benefit. The instrumentation will show which pole dominates.

Alternative considered: keeping the handoff as the owner and special-casing "Chromium already running" by skipping the spawn. Rejected — it leaves the revoke path still killing a browser it did not start, and keeps two lifecycles entangled.

### The loopback screen-sharing stack lives with the browser session; only the tunnel is ephemeral

x11vnc, websockify, and Caddy are all loopback-only and unreachable externally until cloudflared runs. Starting them with the browser session rather than per handoff is therefore consistent with the "no persistent ingress" constraint: no external route exists between handoffs.

This does not increase local risk. Any local process that could reach the VNC port can already reach CDP on 9222, which is strictly more powerful.

Arming a handoff becomes: write a fresh high-entropy token route into the Caddy config, reload Caddy, start cloudflared, verify, print. Revoking becomes: stop cloudflared and remove the token route.

Alternative considered: starting the whole loopback stack per handoff, as today. Rejected — it adds startup cost for no security benefit, given the constraint that external reachability is gated on cloudflared alone.

### Verification moves into the script, and the script only succeeds if the URL works

The script polls the public URL until it returns HTTP 200 with `noVNC` in the body, subject to a deadline. On success it prints exactly one verified URL. On failure it revokes what it started and exits non-zero with the failing phase named.

This turns a multi-turn agent loop into a single tool call, and makes the "never share an unverified bearer URL" rule a property of the script rather than an instruction the agent must remember.

Alternative considered: leaving verification in `SKILL.md`. Rejected — it is the single largest paragraph in the skill and the most likely source of agent round-trips.

### Verification waits before it probes, because probing early makes it slower

Discovered during implementation, and it inverts the obvious approach.

A fresh `trycloudflare.com` hostname is not resolvable at the moment cloudflared
prints it. A lookup that misses is cached as a negative answer, and re-querying
keeps refreshing that negative entry, so an eager polling loop can hold itself
in failure well past actual propagation. Measured in the container:

| Approach | Outcome |
| --- | --- |
| Probe immediately, poll every 1s | Hostname never resolved within 120s |
| Wait 45s quietly, then query once | Resolved on the first query |

This is not a container artifact. Every caching resolver — systemd-resolved,
dnsmasq, a container runtime's embedded DNS — does negative caching, so the same
trap exists on the target host.

The verification therefore waits a quiet grace window before its first lookup,
then backs off progressively, and treats DNS resolution as its own phase
separate from HTTP reachability. The two are different waits with different
causes, and separating them is what makes the remaining cost legible.

**Measured on the target host (x86_64 Debian 13, Kubernetes pod).** Three runs
at each of five grace values, plus three baseline runs at the 20s default:

| grace | first-lookup hits | `url_verified` when it hit |
| --- | --- | --- |
| 5s | 3/3 | ~10.7s |
| 8s | 3/3 | ~13.3s |
| 12s | 3/3 | ~16.7s |
| 16s | 2/3 | ~20.5s |
| 20s | 3/3 sweep, 2/3 baseline | ~25.4s |

Two misses in 18 runs, roughly 11%, and both were large outliers — the lookup
took 40–60s longer than the grace window rather than slightly longer.

Two conclusions the data supports:

1. **There is no propagation floor above 5s.** 5s, 8s, and 12s each hit on all
   three runs, so propagation completed inside 5s for at least nine consecutive
   tunnels.
2. **A longer grace did not prevent the outliers.** The 20s baseline run that
   missed waited 60s for its lookup; four times the grace would not have helped.

One conclusion the data does **not** support: that a longer grace is actively
worse. Misses landed on the two longest values, but with three runs each that is
well within chance — if misses occur at ~11% independently, seeing none in the
nine short-value runs happens about a third of the time. The honest reading is
that misses look independent of the grace window, not that they correlate with
it.

That is enough to choose. Waiting longer costs about 15s on every fast arm and
demonstrably does not buy protection on the slow ones:

| grace | common path | expected, including ~11% outliers |
| --- | --- | --- |
| 5s | 10.7s | ~15.6s |
| 20s | 25.4s | ~29.9s |

The default is therefore 5s, with the backoff handling outliers. It does handle
them: the 16s miss verified at 61s rather than failing.

### Readiness checks replace liveness checks and fixed sleeps

- Xvfb: poll for the X socket instead of `sleep .2` followed by `kill -0`. The current check confirms the process exists, not that the display accepts connections, so it is both slower than necessary in the common case and unreliable in the slow case.
- cloudflared URL discovery: poll at 200ms instead of 1s.
- Port selection: one Python invocation returning all needed ports instead of one per port.

### Caddy's listener port is selected dynamically and its output is not discarded

The current hard-coded `:6081` contradicts the script's own careful dynamic selection for VNC and websockify. Because Caddy's output goes to `/dev/null`, a bind conflict surfaces only as a blank page behind a working tunnel URL — an expensive failure to diagnose. Caddy's port is selected like the others, and its output is captured to the run log.

The Caddyfile keeps a host-agnostic site address with `bind 127.0.0.1`, since binding to `http://127.0.0.1:<port>` rejects the public tunnel Host header.

## Risks / Trade-offs

- **The tunnel turns out to be the dominant phase, so the change delivers little measured speedup** → Accept and report honestly. The correctness fixes stand on their own, and the instrumentation makes the remaining floor visible rather than suspected. Further reduction would require the persistent-ingress option the user has rejected.
- **A long-lived loopback VNC stack is running whenever the browser session is up** → No external route exists without cloudflared, and local reach is already dominated by CDP on 9222. Documented in the security boundary rather than mitigated further.
- **Session state file becomes stale after a crash, so the handoff attaches to a dead display** → The handoff validates the recorded display and CDP endpoint before attaching, and reports a clear "start a browser session first" error rather than attaching blindly.
- **Splitting the lifecycle changes the operator-facing sequence** → `SKILL.md` currently documents the old sequence. The `trim-skill-docs` change rewrites it; these two must not land in an inconsistent state.
- **Caddy reload on arm could drop an in-flight handoff** → Only one handoff is armed at a time; arming while another is active is refused rather than silently replacing it.
- **Run log accumulates timing data over time** → It lives in the private `700` runtime directory, contains no credentials or tunnel tokens, and records phase names and durations only. Tunnel URLs and token paths are never written to it.

## Open Questions

- ~~Is a Cloudflare Quick Tunnel URL routable at the moment cloudflared prints it?~~ **Partly answered: no.** In the container the URL is emitted at ~2.8s and is not resolvable then; the hostname resolves during a quiet window afterwards. What remains unmeasured is *how long* propagation actually takes, because the 20s grace window is a conservative guess that succeeds on its first lookup. Finding the real floor requires probing near it without poisoning the negative cache, and belongs to the target-host measurement.
- What is the shortest safe grace window before the first DNS lookup? This is now the dominant term in arming a handoff, so it is the main remaining latency lever. Target host only.
- Which pole dominates end to end — the session cold start or the tunnel? The container's session start is 0.53s against a 23.8s arm, but attach mode already removes the session from the handoff path, so on the target host the question narrows to how much of the tunnel term is reducible.
- How much of the end-to-end interval sits in agent turns rather than in the script? One manual measurement against the script's entry timestamp settles it.
