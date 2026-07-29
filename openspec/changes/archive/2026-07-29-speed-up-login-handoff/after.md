# Handoff measurements

Host: `x86_64` Debian GNU/Linux 13 (trixie)
Date: 2026-07-29T04:41:53Z

## Baseline (task 1.5) — 3 runs at the current default grace

| run | session total | tunnel_url | dns_resolved | url_verified | handoff total |
| --- | --- | --- | --- | --- | --- |
| 1 | 1.630s | 4.470s | 9.490s | 10.350s | 10.370s |
| 2 | 1.610s | 4.680s | 9.700s | 10.570s | 10.570s |
| 3 | 1.810s | 4.210s | 9.220s | 10.040s | 10.050s |

| metric | min / mean / max |
| --- | --- |
| session total | 1.61 / 1.68 / 1.81 s |
| tunnel_url | 4.21 / 4.45 / 4.68 s |
| dns_resolved | 9.22 / 9.47 / 9.70 s |
| url_verified | 10.04 / 10.32 / 10.57 s |
| handoff total | 10.05 / 10.33 / 10.57 s |

## Still manual

- **Task 1.6** — agent-turn cost. Note the wall clock when you ask for a
  handoff (`T0`), the `# started=` line in the newest `handoff-*.log`
  (`T1`), and when the noVNC canvas becomes operable (`T2`).
- **Task 6.3** — send after revocation. Needs a real authenticated session,
  so run it after logging in.

Raw phase logs: `/home/lineoa/.local/state/line-oa-chat-send/timing/`
