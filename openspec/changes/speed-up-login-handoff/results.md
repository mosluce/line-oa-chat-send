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

## Task 6.3 — send after revocation (target host, authenticated)

The structural claim, verified against a real session:

```
chromium started   Wed Jul 29 04:44:13 2026
handoff log        2026-07-29 04:46:45 +0000     (2m32s later)
dry run            succeeded afterwards, same chromium pid still live
```

`DRY-RUN OK: selected chat '...'; no message was sent.`

The browser predates the handoff, survived arming and revocation, and served a
send immediately after — with no restart. Before this change, revoking killed the
browser the user had just authenticated, so this sequence required a second
Chromium cold start.

## Task 1.6 — where the time actually goes

Measured on the deployed agent (a chat bot), timestamps decoded from the
platform's message IDs; script entry from the phase log.

| Mark | Time (UTC) |
| --- | --- |
| `T0` request sent | 06:41:41.417 |
| `T1` script entry | 06:42:00 (log records whole seconds) |
| `T3` URL delivered | 06:42:17.230 |

| Segment | Duration | Share |
| --- | --- | --- |
| Agent, before the script ran | 18.58 s | 52% |
| Script | ~10.3 s | 29% |
| Agent, after the script returned | ~6.9 s | 19% |
| **Request → URL delivered** | **35.81 s** | |
| User clicks through to an operable canvas | ~5 s | |
| **Request → operable login** | **~41 s** | |

The script's share is inferred: `T1 → T3` is 17.23s, and `after.md` puts the
script at 10.04–10.57s, which fits. A 20s grace would have needed ~25s and does
not fit, which independently confirms the deployment was running the 5s default.

**Agent turns total ~25.5s against ~10.3s of script — 2.5× the thing that was
optimized.** The premise this change started from, that the script was the
bottleneck, does not hold.

## Task 6.8 — the overall picture

| Source | Effect | Basis |
| --- | --- | --- |
| Grace-window tuning | −14.8 s | Measured, `baseline.md` vs `after.md` |
| Structural change (attach mode) | −1.7 s, plus correctness | Removes the second Chromium cold start after revocation. Its real value is that a handoff can be armed while the browser runs and revoking no longer kills the session |
| Removed agent round-trips | Not directly measured; reasoned below | — |

### Why the removed round-trips were probably the largest of the three

Before this change, `SKILL.md` required the agent to fetch the public URL, check
it for noVNC content, and on failure revoke, repair the route, and regenerate —
each step a separate turn. This measurement prices one agent turn at 6.9–18.6s.

The compounding problem is that those turns would have been *spent badly*. The
URL is not reachable when it is printed, so the agent's first check would fail
by construction. It would then retry — and agent-driven retries are exactly the
eager polling that keeps the resolver's negative cache alive, which was measured
to prevent resolution for over 120 seconds.

So the old design put a human-latency retry loop on top of a failure mode that
retrying makes worse. The realistic old cost is therefore several turns plus a
poisoned cache, not one clean verification.

This is reasoning, not measurement: the original flow was never timed, because
the instrumentation arrived with the change and the old code could not produce a
phase log. It is recorded as an argument, not a number.

### What this says about where to look next

Optimizing the script further has poor returns. The remaining script budget is
4.45s tunnel registration (out of scope by decision), 5.00s grace (measured
floor), and 0.87s DNS + HTTP.

The agent segments are now the dominant cost, and the largest single one is the
18.58s *before the script runs at all* — reading the skill, deciding, and
issuing the first tool call. That is a documentation and tool-surface question,
not a shell-script one. A plausible next step is collapsing preflight, session
start, and arming into a single command so the agent makes one decision instead
of three.

## Not claimed

- No overall speedup for the change as a whole. The pre-change baseline does not
  exist, and the agent-round-trip saving is argued rather than measured.
- No claim that a longer grace is worse. Misses landed on longer values, but
  three runs per value is well within chance.
