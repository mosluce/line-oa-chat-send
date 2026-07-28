## Context

The scripts assume a Linux host with Xvfb, x11vnc, websockify, noVNC assets, Caddy, cloudflared, Chromium, and a Python runtime with Playwright. Development happens on macOS on Apple Silicon. The verification tasks in `speed-up-login-handoff` — the refusal matrix, the forced verification failure, the arm/revoke lifecycle — and the four-way environment matrix in `trim-skill-docs` currently have nowhere to run.

A container solves execution but introduces a measurement trap. The central open question in `speed-up-login-handoff` is which pole dominates handoff startup: Chromium cold start or Cloudflare Quick Tunnel registration. On Docker Desktop on Apple Silicon both poles are distorted, in the same direction but by different and unpredictable amounts:

- Chromium is slowed by the VM's CPU allocation and by bind-mount filesystem overhead, would be catastrophically slowed by running an amd64 image under emulation, and runs on different silicon from the likely x86_64 target. It is simultaneously *sped up* by using a small throwaway profile instead of a real authenticated one.
- Tunnel registration is slowed because Quick Tunnels prefer QUIC over UDP, which Docker Desktop's NAT can degrade into an HTTP/2 fallback, and because egress goes through a workstation network rather than a datacenter link.

The ratio between the two poles is therefore unreliable, and the ratio is the entire question. This has to be a stated constraint, not a footnote, or someone will read container numbers as an answer.

One property makes the container unusually safe here: phase timing and every refusal path exercise Chromium loading the LINE **login** page. None of them require an authenticated session, so the container never needs a real profile or any credential.

## Goals / Non-Goals

**Goals:**

- Give the repository's scripts a reproducible Linux execution surface.
- Make failure paths cheap to exercise by varying the environment declaratively instead of breaking a host by hand.
- Keep the container credential-free by construction.
- State, in the specification rather than in prose, what container results may and may not be used to conclude.

**Non-Goals:**

- Producing latency attribution or final speedup numbers. Those belong to the target host.
- Running the scripts in production from a container. This is a test and rehearsal surface.
- Supporting macOS or Windows as script targets. Linux remains the only target; the container is how a non-Linux workstation reaches it.
- Adding CI execution. The image is usable from CI later, but wiring that is out of scope.

## Decisions

### The image is architecture-native, and a mismatch fails loudly

The image builds and runs for the host architecture. An amd64 image under emulation on Apple Silicon would make every timing observation meaningless and every test slow enough to be abandoned, so an architecture mismatch is detected at container start and fails with a clear message rather than proceeding slowly.

Chromium comes from the distribution's own package rather than Playwright's managed download, since Playwright's Chromium builds do not cover linux-arm64 uniformly. This matches how the scripts already behave: `start_line_oa_chromium.sh` discovers a system Chromium, and `setup_line_oa_runtime.sh --skip-browser-install` exists precisely for the CDP-only case.

### The browser profile lives on a container volume; repository sources are bind-mounted read-only

Two different concerns, two different mechanisms. The Chromium profile is I/O-heavy, so it goes on a container-native volume where filesystem performance is closest to native. The repository scripts are small and edited constantly, so they are bind-mounted read-only for fast iteration without copying the image on every change.

Read-only mounting also prevents a test run from modifying the working tree.

### A real authenticated profile is never mounted into the container

The container is credential-free by construction, not by convention. Every behavior it needs to exercise — startup phases, refusal paths, dependency detection, arm and revoke — works against the LINE login page. Mounting a real profile would add no test coverage and would put a live session inside a throwaway environment.

A consequence worth stating: the container cannot verify a successful message send end-to-end. That verification stays on the target host with a real session.

### Environment variants are build targets, not separate definitions

The variants — full, missing Python/Playwright runtime, missing handoff dependencies, present-but-unauthenticated profile — derive from one definition so they cannot drift apart. `trim-skill-docs` names exactly these four for `doctor.sh`; deriving them from a common base means a change to the base propagates to all of them.

Alternative considered: separate definitions per variant. Rejected — four copies of an environment definition diverge, and a stale variant produces a false pass.

### Tunnel-dependent tests are opt-in and time-bounded

Arming a handoff creates a publicly reachable URL through an outbound tunnel, requiring no published ports but exposing a browser to the internet for the life of the tunnel. Most tests — the refusal matrix, dependency detection, arm-refusal cases — never reach the point of creating a tunnel.

The default test path therefore requires no external egress. Tests that create a real tunnel are explicitly opted into and inherit the handoff's own TTL bound. The container's browser holds no session, so the exposure is a blank LINE login page, but the default should not silently open one.

### The container's authority is scoped in the specification

Container results are authoritative for: script behavior, refusal and error paths, dependency detection and remediation messages, and arm/revoke lifecycle correctness.

Container results are **not** authoritative for: which startup phase dominates, absolute phase durations, or any reported speedup figure. Those require a run on the target Linux host.

Writing this as a requirement rather than a README note is deliberate — the numbers are easy to produce and tempting to quote.

## Risks / Trade-offs

- **Container numbers get quoted as latency conclusions anyway** → The scoping requirement is explicit, and the measurement tasks in `speed-up-login-handoff` are marked target-host-only so the boundary appears where the work happens, not only in this change.
- **Container passes but the target host fails, because of a distribution or architecture difference** → The container is a rehearsal surface, not a substitute for target-host verification. Both changes retain their target-host verification tasks.
- **The image drifts from what the target host actually has** → The image installs the same dependencies the scripts check for, so `doctor.sh` running clean inside the container is itself a consistency signal.
- **Maintaining a container becomes its own cost for a small repository** → Kept minimal: one definition, variants as build targets, no orchestration, no CI wiring.
- **A test tunnel is left running after a failed test** → Tunnel tests are opt-in and bounded by the handoff TTL, and container teardown removes the tunnel with the container.

## Open Questions

- ~~What is the target host's architecture and distribution?~~ **Resolved: arm64 Debian.** The container matches the target in both, so there is no silicon difference and no emulation on either side, and one of the anticipated distortions does not apply. The remaining divergences are the virtualized CPU and filesystem, the throwaway profile instead of a real one, the workstation egress path, and `seccomp=unconfined`. Both startup poles remain distorted by different and unpredictable amounts, so the limit on latency authority stands — matching architecture narrows the gap without closing it. Recorded in `containers/README.md`.
