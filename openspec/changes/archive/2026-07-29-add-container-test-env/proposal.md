## Why

Every script in this repository targets Linux, but development happens on macOS, so there is currently no place to execute the verification tasks that `speed-up-login-handoff` and `trim-skill-docs` depend on. The repository also has no test surface at all — no tests, and CI that only publishes on tags. Both problems are solved by the same thing: a reproducible Linux container that can run the scripts and be deliberately broken to exercise their failure paths.

## What Changes

- Add a container image that provides the full Linux runtime the scripts expect: X display server, VNC server, websockify with noVNC assets, HTTP front end, tunnel client, Chromium, and a Python/Playwright runtime.
- Add environment variants of that image that are missing specific dependencies, so failure and remediation paths can be exercised without hand-breaking a real host.
- Add a documented way to run the repository's scripts inside the container against a throwaway browser profile.
- Constrain what the container may be used to conclude: it is authoritative for behavior, refusal paths, and dependency detection, and explicitly **not** authoritative for latency attribution or reported speedup numbers.
- Make tunnel-dependent tests opt-in rather than part of the default test path, since arming a real handoff creates a publicly reachable URL.
- Annotate the tasks in `speed-up-login-handoff` and `trim-skill-docs` that must run on the real target host rather than in the container.

## Capabilities

### New Capabilities
- `container-test-env`: a reproducible Linux environment for executing and deliberately breaking this repository's scripts, including its dependency variants, its credential and egress boundaries, and the limits on what its results may be used to conclude.

### Modified Capabilities
<!-- No existing specs in openspec/specs/ yet; the capability above is new. -->

## Impact

- New container definition and its environment variants.
- New documentation for running the scripts inside the container, referenced from `CONTRIBUTING.md` by the `trim-skill-docs` change.
- `speed-up-login-handoff` — its verification tasks gain an execution surface; its measurement tasks gain an explicit "target host only" marker.
- `trim-skill-docs` — its `doctor.sh` environment-variant task gains an execution surface.
- No change to any script's behavior, network exposure model, or security boundary. The container consumes the scripts as they are.
- Ordering: this change lands before the other two, because their verification tasks are otherwise blocked.
