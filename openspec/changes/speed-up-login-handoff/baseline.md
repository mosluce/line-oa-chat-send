# Handoff measurements

Host: `x86_64` Debian GNU/Linux 13 (trixie)
Date: 2026-07-29T04:15:06Z

## Baseline (task 1.5) — 3 runs at the current default grace

| run | session total | tunnel_url | dns_resolved | url_verified | handoff total |
| --- | --- | --- | --- | --- | --- |
| 1 | 1.750s | 5.270s | 65.860s | 66.730s | 66.740s |
| 2 | 1.520s | 4.970s | 24.990s | 25.830s | 25.840s |
| 3 | 1.620s | 3.630s | 23.640s | 24.490s | 24.510s |

| metric | min / mean / max |
| --- | --- |
| session total | 1.52 / 1.63 / 1.75 s |
| tunnel_url | 3.63 / 4.62 / 5.27 s |
| dns_resolved | 23.64 / 38.16 / 65.86 s |
| url_verified | 24.49 / 39.02 / 66.73 s |
| handoff total | 24.51 / 39.03 / 66.74 s |

## Grace-window sweep (task 1.7) — 3 runs per value

Read-off: `lookup wait` is the time from the tunnel URL being emitted to
the hostname resolving — the grace window plus the lookup itself. When it
is within ~1.5s of the grace value the first lookup hit. Meaningfully
larger means the first lookup missed and backoff recovered it, which is
already refreshing the negative cache. Pick the smallest value that hits
on every run.

| grace | run | lookup wait | over grace | first-lookup hit? | url_verified |
| --- | --- | --- | --- | --- | --- |
| 5s | 1 | 5.010s | +0.01s | yes | 10.700s |
| 5s | 2 | 5.010s | +0.01s | yes | 10.700s |
| 5s | 3 | 5.020s | +0.02s | yes | 10.740s |
| 8s | 1 | 8.020s | +0.02s | yes | 13.310s |
| 8s | 2 | 8.020s | +0.02s | yes | 12.270s |
| 8s | 3 | 8.010s | +0.01s | yes | 14.190s |
| 12s | 1 | 12.010s | +0.01s | yes | 17.540s |
| 12s | 2 | 12.010s | +0.01s | yes | 16.040s |
| 12s | 3 | 12.020s | +0.02s | yes | 16.710s |
| 16s | 1 | 56.570s | +40.57s | no (backoff) | 61.010s |
| 16s | 2 | 16.010s | +0.01s | yes | 19.840s |
| 16s | 3 | 16.020s | +0.02s | yes | 21.100s |
| 20s | 1 | 20.020s | +0.02s | yes | 25.910s |
| 20s | 2 | 20.010s | +0.01s | yes | 25.270s |
| 20s | 3 | 20.020s | +0.02s | yes | 25.150s |

**Smallest grace with a first-lookup hit on every run: 5s.**

Apply it as the default in `scripts/start_line_oa_vnc_handoff.sh`:

```bash
verify_grace="${LINE_OA_SEND_CHAT_HANDOFF_VERIFY_GRACE:-5}"
```

## Still manual

- **Task 1.6** — agent-turn cost. Note the wall clock when you ask for a
  handoff (`T0`), the `# started=` line in the newest `handoff-*.log`
  (`T1`), and when the noVNC canvas becomes operable (`T2`).
- **Task 6.3** — send after revocation. Needs a real authenticated session,
  so run it after logging in.

Raw phase logs: `/home/lineoa/.local/state/line-oa-chat-send/timing/`
