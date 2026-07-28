# Container test environment

A reproducible Linux environment for running and deliberately breaking this
repository's scripts. It exists because the scripts target Linux while
development happens elsewhere, and because failure paths are far cheaper to
exercise by picking a variant than by breaking a real host by hand.

## What this is and is not authoritative for

| Authoritative for | Not authoritative for |
| --- | --- |
| Script behavior | Which startup phase dominates |
| Refusal and error paths | Absolute phase durations |
| Dependency detection and remediation messages | Any reported speedup figure |
| Handoff arm/revoke lifecycle | End-to-end message send |

Latency results from this container are usable for rehearsing a measurement and
for same-host before-and-after comparison. They are **not** an answer to which
phase dominates handoff startup. Both poles are distorted here, in the same
direction but by different and unpredictable amounts:

- **Chromium** is slowed by the VM's CPU allocation and filesystem layer, and is
  simultaneously *sped up* by using a throwaway profile instead of a real one.
- **Tunnel registration** is slowed because Quick Tunnels prefer QUIC over UDP,
  which a desktop VM's NAT can degrade into an HTTP/2 fallback, and because
  egress goes through a workstation network rather than a datacenter link.

## Distance from the target host

The target is **arm64 Debian**, so the container matches it in architecture and
distribution. Chromium, the handoff dependencies, and the Playwright runtime are
the same packages built for the same instruction set — there is no silicon
difference and no emulation on either side.

What still differs, and why timing conclusions stay out of scope:

| Differs | Effect |
| --- | --- |
| Virtualized CPU and filesystem (Docker Desktop VM) | Inflates Chromium cold start |
| Throwaway profile instead of a real authenticated one | Deflates Chromium cold start |
| Egress via a workstation network, QUIC through the VM's NAT | Inflates tunnel registration |
| `seccomp=unconfined`, absent on the target | Changes sandbox setup cost |

Both startup poles are still distorted, in the same direction but by different
and unpredictable amounts — and the ratio between them is the entire question
`speed-up-login-handoff` needs answered. Matching architecture narrows the gap;
it does not close it.

Two further divergences from a real host, both introduced by the container and
neither present on the target:

- `--security-opt seccomp=unconfined`, because Docker's default seccomp filter
  blocks the namespace creation Chromium's zygote needs. This drops the
  container's outer confinement so Chromium can build its own sandbox; the
  browser's sandbox stays intact. Preferred over `--no-sandbox`, which would
  mean teaching the scripts a container-only flag.
- `--shm-size=1g`, because Chromium exhausts the 64MB default and dies with a
  broken zygote pipe.

## Credentials

The container is credential-free by construction, not by convention. Every
behavior it covers works against the LINE **login** page, so no session is ever
needed. `run.sh` builds every mount itself and forwards no Docker flags, and it
refuses an inherited `LINE_OA_SEND_CHAT_CHROMIUM_PROFILE` rather than silently
ignoring it. Do not mount a real profile.

## Variants

All four derive from one Dockerfile; the table in `build.sh` is the only place
they differ, and their base layers are byte-identical.

| Variant | Handoff deps | Playwright runtime | Profile |
| --- | --- | --- | --- |
| `full` | yes | yes | empty |
| `no-runtime` | yes | no (and no `uv`) | empty |
| `no-handoff-deps` | no | yes | empty |
| `unauth-profile` | yes | yes | initialized, no session |

`no-runtime` omits `uv` deliberately: `run_line_oa_chat.sh` falls back to
`uv run --with playwright`, so leaving `uv` in place would let the variant
silently succeed and prove nothing.

`unauth-profile` runs Chromium once at build time so its profile is initialized
and previously used rather than an empty directory, which would make it
identical to `full`.

## Usage

```bash
# Build all four variants (native architecture only)
containers/build.sh

# Build one
containers/build.sh full

# Run a command in a variant; default is an interactive shell
containers/run.sh full bash
containers/run.sh no-runtime bash scripts/run_line_oa_chat.sh --help

# Start a browser session and check CDP from inside
containers/run.sh full bash -lc '
  bash scripts/start_line_oa_chromium.sh >/tmp/c.log 2>&1 &
  sleep 20
  curl -fsS http://127.0.0.1:9222/json/list'
```

The repository is mounted read-only at `/workspace`. The browser profile lives
on a per-variant Docker volume, never a host path. No port is published, so
nothing is externally reachable unless a command inside starts an outbound
tunnel itself.

## Tests

```bash
# Default path: no external exposure
containers/test/default.sh

# Opt-in: creates a real, externally reachable Cloudflare Quick Tunnel
LINE_OA_TEST_ALLOW_TUNNEL=1 containers/test/tunnel.sh 60
```

The default path covers the architecture guard, dependency presence, isolation,
browser session startup, and every handoff refusal that happens before a tunnel
would be created. The tunnel test is separate and gated because it genuinely
exposes the container's browser for the life of the tunnel.

## Teardown

Containers run with `--rm` and clean themselves up. Profile volumes persist on
purpose, mirroring the real system's persistent profile, so removing them is
explicit:

```bash
containers/reset.sh            # drop profile volumes
containers/reset.sh --images   # also drop the built images
```

## Architecture guard

The container refuses to run under emulation. `run.sh` passes the host
architecture in, and the entrypoint compares it against the container's own;
a mismatch, or a missing host architecture, exits non-zero. Emulated Chromium
would be slow enough to make every test unpleasant and every timing meaningless.

## Known behavior worth remembering

Chromium writes a `SingletonLock` into the profile recording the hostname
holding it. Docker assigns a random hostname per container, so a lock left by a
killed container is read as held "on another computer" and every later run is
refused. `run.sh` pins a per-variant hostname so Chromium recognizes a stale
lock as its own and breaks it. A volume already poisoned by a random-hostname
lock needs `containers/reset.sh` once. The same stale lock can strand a
hard-killed Chromium on a real host.
