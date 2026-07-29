# Results

Target host: x86_64 Debian 13 (trixie), Kubernetes pod.
Raw data: `baseline.md` (grace 20s), `after.md` (grace 5s).

## What was measured

| | before (grace 20s) | after (grace 5s) |
| --- | --- | --- |
| `url_verified` min / median / max | 24.49 / 25.83 / 66.73 s | 10.04 / 10.35 / 10.57 s |
| common-path mean (excluding the outlier) | 25.16 s | 10.32 s |
| spread across runs | 1.34 s (common path) | 0.53 s |

**Common path: 25.2s → 10.3s, a saving of 14.8s (59%).**

Composition of the remaining 10.3s:

| Component | Time | Reducible? |
| --- | --- | --- |
| Tunnel registration (`tunnel_url`) | 4.45 s | Only with a persistent or named tunnel, which is explicitly out of scope |
| Grace window | 5.00 s | Already measured as the smallest value that hit on every run |
| DNS lookup | 0.02 s | No — it hits on the first query |
| HTTP verification | 0.85 s | No |

Tunnel registration is now the largest single component, and shrinking it was
ruled out at proposal time. The grace window is the second, and 5s is the
smallest value the sweep supported.

## What this figure does and does not cover

It covers **the grace-window change only.**

The task 1.5 baseline was itself taken with the restructured code — attach mode
and in-script verification already in place, just at a 20s grace. The original
handoff was never measured, because the instrumentation arrived with this
change and the old code could not produce a phase log. There is therefore no
honest before/after for the change as a whole.

The full speedup has three sources. Only one is measured:

| Source | Status |
| --- | --- |
| Grace-window tuning | **Measured: −14.8s on the common path** |
| Structural change (attach mode) | Not measured as latency. It removes the second Chromium cold start after revocation, worth ~1.7s, but its real value is correctness — a handoff can be armed while the browser runs, and revoking no longer kills the session |
| Removed agent round-trips | **Not yet measured** — task 1.6 |

Before this change the agent had to fetch the public URL, check it for noVNC
content, and on failure revoke, repair, and regenerate — each a separate turn.
That cost is plausibly larger than everything above, and it is the one number
still missing.

## Outliers

Roughly 1 arm in 9 hits a slow tunnel: the DNS lookup runs 40–60s past the
grace window instead of resolving immediately. The `after` sample of three
contains no outlier, which is luck rather than improvement — the rate is a
property of the tunnel service and is unchanged by the grace value.

So the comparison above is deliberately made on the common path. Comparing
means would flatter the result, because the `before` sample happened to include
an outlier and the `after` sample happened not to.

When an outlier does occur, the backoff recovers rather than failing: the
observed worst case verified at 61s.

## Not claimed

- No overall speedup for the change as a whole. The pre-change baseline does not
  exist.
- No claim that a longer grace is worse. Misses landed on longer values, but
  three runs per value is well within chance.
