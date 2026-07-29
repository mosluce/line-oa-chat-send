## 1. Instrument the current handoff and get a baseline

- [x] 1.1 Add a phase-timing helper that records a monotonic timestamp under a named phase and appends it to a run log in the private runtime directory with restrictive permissions
- [x] 1.2 Instrument the existing `start_line_oa_vnc_handoff.sh` phases: script entry, Xvfb ready, Chromium spawned, CDP reachable, LINE page present, x11vnc listening, websockify listening, Caddy listening, tunnel URL emitted
- [x] 1.3 Add a public-URL reachability probe that records the interval from tunnel URL emitted to first HTTP 200 containing `noVNC`
- [x] 1.4 Print a phase summary at the end of the run; assert the summary contains no URL, route token, or credential
- [ ] 1.5 **TARGET HOST ONLY** Run the instrumented handoff 2–3 times on the Linux host and record the baseline numbers in the change directory
- [ ] 1.6 **TARGET HOST ONLY** Record one manual end-to-end measurement: agent request time, script entry time, and the moment the noVNC canvas becomes operable, to quantify the portion outside the script
- [ ] 1.7 **TARGET HOST ONLY** Answer the design's open questions from the baseline. Partly answered in the container: the URL is *not* routable when printed (emitted ~2.8s, resolves only during a later quiet window), and eager probing poisons the resolver's negative cache. What remains: the shortest safe DNS grace window, now the dominant term in arming

> Tasks 1.5–1.7 must run on the target Linux host. Step-by-step procedure:
> `target-host-runbook.md` in this change directory.
>
> Tasks 1.5–1.7 must run on the target Linux host. The container test
> environment distorts both startup poles unpredictably and is not authoritative
> for phase dominance, absolute durations, or reported speedup. See
> `containers/README.md`.

## 2. Cheap latency and reliability fixes on the current structure

- [x] 2.1 Replace the fixed `sleep .2` Xvfb wait with a poll on the X socket, with a deadline and a named error on timeout
- [x] 2.2 Reduce cloudflared URL discovery polling from 1s to 200ms, keeping the overall deadline
- [x] 2.3 Collapse the two `pick_loopback_port` Python invocations into a single call returning all required ports
- [x] 2.4 Remove the duplicated dependency-check loop
- [x] 2.5 Select the Caddy listener port dynamically instead of hard-coding `:6081`, keeping the host-agnostic site address with `bind 127.0.0.1`
- [x] 2.6 Stop discarding Caddy output; route it to the run log so a bind failure is reported instead of surfacing as a blank page
- [ ] 2.7 Re-run the instrumented handoff and compare against the 1.5 baseline

## 3. Give the browser session a durable, discoverable lifecycle

- [x] 3.1 Make `start_line_oa_chromium.sh` own an X display that is not trapped to a single Chromium invocation
- [x] 3.2 Write a session state file (display, profile directory, CDP endpoint) into the private runtime directory with restrictive permissions once CDP is reachable
- [x] 3.3 Add a stale-state check helper: a recorded session counts as present only when its display and CDP endpoint both respond
- [x] 3.4 Start x11vnc, websockify, and Caddy with the browser session, all bound to loopback, on dynamically selected ports, with output captured
- [x] 3.5 Keep the existing refusal to start a second Chromium when the configured CDP endpoint already responds
- [x] 3.6 Verify no externally reachable route to the browser exists while a session is up and no handoff is armed

## 4. Convert the handoff into an attach-only, verified operation

- [x] 4.1 Remove Chromium and Xvfb ownership from `start_line_oa_vnc_handoff.sh`; read the session state file instead
- [x] 4.2 Fail non-zero with a "start a browser session first" message when no live session is found
- [x] 4.3 Implement arm: generate a fresh route token, write the token route into the Caddy config, reload Caddy, start cloudflared
- [x] 4.4 Refuse to arm when another handoff is already armed, leaving the existing one intact
- [x] 4.5 Implement verify: poll the public URL until HTTP 200 containing `noVNC`, subject to a deadline; print the URL only after verification passes
- [x] 4.6 On verification failure, revoke everything the handoff started, print no URL, and exit non-zero naming the failing phase
- [x] 4.7 Implement revoke: stop cloudflared, remove the token route, reload Caddy, and leave Chromium and the display running
- [x] 4.8 Wire TTL expiry to the same revoke path as explicit revocation
- [x] 4.9 Preserve the existing explicit login-purpose gate and the 60–3600s TTL range check

## 5. Scripted session shutdown

- [x] 5.1 Add a session shutdown script that resolves the Chromium root process from the recorded session state, not from a process-name pattern
- [x] 5.2 Revoke any armed handoff before terminating the session
- [x] 5.3 Send a graceful termination signal, wait for exit, then stop the display and the loopback screen-sharing components
- [x] 5.4 Verify the CDP endpoint is unreachable and leave the persistent profile directory unmodified
- [x] 5.5 On graceful-timeout, report the blocker and exit non-zero without escalating to a forced kill
- [x] 5.6 Remove or invalidate the session state file on successful shutdown

## 6. Verification

> Tasks 6.1–6.7 can be rehearsed in the container test environment before the
> target-host run; `containers/test/default.sh` already covers the pre-tunnel
> refusal cases against the current scripts. Task 6.8 is target-host only.

- [x] 6.1 Arm a handoff while a browser session is running and confirm it succeeds and the session is uninterrupted
- [x] 6.2 Revoke the handoff and confirm Chromium, the display, and the authenticated profile survive
- [ ] 6.3 **TARGET HOST ONLY** Send a message immediately after revocation without restarting the browser (needs a real authenticated LINE session, which the credential-free container cannot provide)
- [x] 6.4 Arm a second handoff on the same session to confirm mid-session re-authentication works
- [x] 6.5 Confirm the handoff refuses to arm with no session, with a stale session state, without the login purpose, with an out-of-range TTL, and while another handoff is armed
- [x] 6.6 Force a verification failure and confirm no URL is printed, everything started is revoked, and the exit code is non-zero
- [x] 6.7 Confirm the run log contains phase timings and no URL, route token, or credential
- [ ] 6.8 **TARGET HOST ONLY** Record the final end-to-end measurement against the 1.5 and 1.6 baselines and report the actual speedup, including the portion attributable to removed agent round-trips

## 6a. Findings surfaced by the container test environment

- [x] 6a.1 The CDP "already running" guard in `start_line_oa_chromium.sh` sits *behind* display setup, so a second start with no `DISPLAY` fails at Xvfb ("could not start private Xvfb display :99") instead of reporting that a session is already running. The safety property holds, but the diagnostic is misleading. Move the session check ahead of display setup — it is cheaper and more meaningful, and attach mode makes it the first thing that should run.
- [x] 6a.2 Chromium writes a `SingletonLock` into the profile recording the hostname that holds it. A hard-killed Chromium leaves the lock behind, and a later start refuses the profile as in use "on another computer" whenever the hostname differs. Session shutdown should clear a stale lock it owns, and startup should report this condition distinctly rather than as a generic launch failure.

## 7. Handoff to the docs change

> Recorded in `docs-handoff.md` in this change directory.

- [x] 7.1 List every `SKILL.md` and `README.md` statement invalidated by this change: handoff ownership of Chromium, agent-performed URL verification, prose shutdown procedure, and the fixed-port pitfalls now enforced in code
- [x] 7.2 Record the new operator sequence and script names so `trim-skill-docs` can document them without re-deriving the design
