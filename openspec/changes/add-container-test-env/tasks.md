## 1. Base image

- [x] 1.1 Choose a Linux base and confirm it packages Xvfb, x11vnc, websockify, noVNC assets, Caddy, and Chromium for the host architecture
- [x] 1.2 Add the tunnel client from its signed vendor repository, matching the instructions the handoff script already prints
- [x] 1.3 Provision the Python runtime with Playwright without a browser download, using the existing skip-browser-install path
- [x] 1.4 Add an architecture guard at container start that exits non-zero on a mismatch with the host architecture
- [x] 1.5 Build natively for the host architecture and confirm no emulation layer is engaged

## 2. Runtime wiring

- [x] 2.1 Place the Chromium profile on a container-native volume, not a host bind mount
- [x] 2.2 Mount repository sources read-only and confirm a test run cannot modify the working tree
- [x] 2.3 Confirm no host path containing a real authenticated profile can be mounted by the documented run commands
- [x] 2.4 Start a browser session inside the container and confirm the CDP endpoint responds and the LINE login page loads
- [x] 2.5 Confirm no port is published and nothing is externally reachable while no handoff is armed

## 3. Environment variants

- [x] 3.1 Derive all variants from the common base as build targets
- [x] 3.2 Add the full variant
- [x] 3.3 Add a variant without the Python/Playwright runtime
- [x] 3.4 Add a variant without the handoff dependencies
- [x] 3.5 Add a variant with a present but unauthenticated profile
- [x] 3.6 Confirm a base dependency change propagates to every variant without a separate edit

## 4. Test paths

- [x] 4.1 Define a default test path that completes without creating any externally reachable URL
- [x] 4.2 Make tunnel-creating tests opt-in, bounded by the handoff TTL, and removed with the container
- [x] 4.3 Document how to run the repository's scripts inside the container for each variant
- [x] 4.4 Confirm container teardown leaves no tunnel, no volume, and no process behind

## 5. Prove the variants drive real verdicts

> Verdict-level checks moved to `trim-skill-docs` task group 2, because they
> need `scripts/doctor.sh`, which that change creates: a single usable /
> not-usable summary, "authentication required" as a verdict distinct from a
> broken environment, and "no remediation widens a network binding". What
> remains here is proving each variant actually presents the environment state
> those checks will consume, against the dependency detection that exists today.
> All four are asserted in `containers/test/default.sh`.

- [x] 5.1 Confirm the full variant presents every dependency: Xvfb, x11vnc, websockify, noVNC assets, Caddy, cloudflared, Chromium, and an importable Playwright runtime
- [x] 5.2 Confirm the missing-runtime variant makes `run_line_oa_chat.sh` report that no Python runtime with Playwright was found
- [x] 5.3 Confirm the missing-handoff-dependency variant makes the handoff script name the exact missing commands and print operator install instructions without invoking a package manager
- [x] 5.4 Confirm the unauthenticated-profile variant presents an initialized, previously-used, session-free profile

## 6. Scope the container's authority

- [x] 6.1 Document that container results are authoritative for behavior, refusal and error paths, dependency detection, and arm/revoke lifecycle
- [x] 6.2 Document that they are not authoritative for phase dominance, absolute durations, or reported speedup
- [x] 6.3 Record the distortions that motivate the limit: virtualized CPU and filesystem, architecture difference from the target, throwaway rather than real profile, and tunnel egress path
- [x] 6.4 Resolve the open question on the target host's architecture and distribution, and record how far it diverges from the container (target is arm64 Debian: architecture and distribution match, so no silicon difference and no emulation; virtualization, throwaway profile, egress path, and seccomp=unconfined still differ)

## 7. Wire into the dependent changes

- [x] 7.1 Mark `speed-up-login-handoff` tasks 1.5, 1.6, 1.7, and 6.8 as requiring execution on the target Linux host
- [x] 7.2 Note in `speed-up-login-handoff` that tasks 6.1 through 6.7 can be rehearsed in the container before the target-host run
- [x] 7.3 Note in `trim-skill-docs` task 2.6 that its four environment variants are provided by this change
- [x] 7.4 Confirm both dependent changes still hold their own target-host verification rather than delegating it to the container
