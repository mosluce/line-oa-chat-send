# Target-host runbook

The six tasks that cannot run in the container: 1.5, 1.6, 1.7, 2.7, 6.3, 6.8.

Target is **arm64 Debian**. The container matches it in architecture and
distribution, so what the container could not settle is timing — it distorts both
startup poles by different and unpredictable amounts — and anything needing a
real authenticated LINE session.

## Do the measurements before logging in

This ordering is a safety property, not a preference.

```
1. Deploy and preflight      ─┐
2. Measure (not logged in)    ├─  exposes only a login page
3. Log in, once               ─┘
4. Send verification (6.3)        needs the real session
```

Once the profile is authenticated, arming a handoff exposes the **live LINE OA
back office** to whoever holds the URL. The grace-window sweep in step 2 arms a
handoff roughly fifteen times. Doing that against an authenticated profile means
fifteen real exposures of a live account.

None of the measurements need a session. Every phase is Chromium loading the
**login** page — the same thing the container measures. So run all of step 2
first, then log in once at the end.

## 1. Deploy and preflight

```bash
git clone -b docs/openspec-change-proposals https://github.com/mosluce/line-oa-chat-send.git
cd line-oa-chat-send
bash scripts/doctor.sh
```

`doctor.sh` names anything missing and prints its remediation. Run the installs
as an identity with package permission — the scripts never invoke `sudo` or a
package manager themselves:

```bash
sudo apt-get update
sudo apt-get install -y xvfb x11vnc novnc websockify caddy chromium chromium-sandbox
```

`chromium-sandbox` is a separate Debian package and is easy to miss. Without it
Chromium aborts with `No usable sandbox!` and the launch failure looks generic.

`cloudflared` comes from Cloudflare's own signed repository; `doctor.sh` prints
the exact three commands.

Python runtime:

```bash
bash scripts/setup_line_oa_runtime.sh \
  --runtime-dir "$HOME/.local/share/line-oa-runtime" --skip-browser-install
export LINE_OA_PYTHON="$HOME/.local/share/line-oa-runtime/venv/bin/python"
```

Re-run `bash scripts/doctor.sh`. Expect **exit 3** — usable, authentication
required. That is the correct state at this point, not a failure.

```bash
export RT="${XDG_STATE_HOME:-$HOME/.local/state}/line-oa-chat-send"
```

## 2. Measurements — still logged out

### Task 1.5 — baseline

```bash
for i in 1 2 3; do
  bash scripts/start_line_oa_chromium.sh
  LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login bash scripts/start_line_oa_vnc_handoff.sh
  bash scripts/stop_line_oa_vnc_handoff.sh
  bash scripts/stop_line_oa_chromium.sh
done

cat "$RT"/timing/session-*.log
cat "$RT"/timing/handoff-*.log
```

Container figures for comparison — **not** a target for the host to match, only a
shape to recognise:

```
session   0.53s total   (display 0.06s, CDP 0.22s)
handoff  23.77s total   (route 0.04s, tunnel_url 2.79s,
                         dns_resolved 22.82s, url_verified 23.76s)
```

### Task 1.7 — the grace window

This is the dominant term. The default 20s is a conservative guess; the real
propagation floor is unmeasured.

Why it cannot be found by simply polling faster: a fresh `trycloudflare.com`
hostname is not resolvable when cloudflared prints it, and a lookup that misses
is cached as a negative answer. Re-querying keeps refreshing that entry, so
eager probing holds itself in failure. Each arm gets a **new hostname**, which is
why a sweep works at all — runs cannot poison each other.

```bash
bash scripts/start_line_oa_chromium.sh

for g in 5 8 12 16 20; do
  for i in 1 2 3; do
    LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login \
    LINE_OA_SEND_CHAT_HANDOFF_VERIFY_GRACE=$g \
      bash scripts/start_line_oa_vnc_handoff.sh >/tmp/arm-$g-$i.log 2>&1
    echo "grace=$g run=$i :: $(grep -E 'dns_resolved|url_verified|FAILED' /tmp/arm-$g-$i.log | tr '\n' ' ')"
    bash scripts/stop_line_oa_vnc_handoff.sh --quiet
    sleep 5
  done
done

bash scripts/stop_line_oa_chromium.sh
```

Read `dns_resolved` against the grace value:

| Observation | Meaning |
| --- | --- |
| `dns_resolved` ≈ grace | Resolved on the first query. This grace is sufficient. |
| `dns_resolved` > grace + 5 | First query missed; backoff recovered it. Already refreshing the negative cache. |
| `FAILED_dns_resolved` | Too short. |

Take the **smallest value that shows "≈ grace" on all three runs**. Anything
smaller trades a reliable arm for a couple of seconds.

Apply it by changing the default in `scripts/start_line_oa_vnc_handoff.sh`:

```bash
verify_grace="${LINE_OA_SEND_CHAT_HANDOFF_VERIFY_GRACE:-<measured value>}"
```

Record the sweep output in this directory as `baseline.md`.

### Task 1.6 — how much sits in agent turns

Only measurable by hand, and only once.

| Mark | Where it comes from |
| --- | --- |
| `T0` | Wall clock when you ask for a handoff |
| `T1` | The `# started=` line at the top of the newest `handoff-*.log` (UTC) |
| `T2` | Wall clock when the noVNC canvas is actually operable |

`T1 − T0` is the agent turn. `T2 − T1` is the script plus first paint. `T1 − T0`
is what moving verification into the script was meant to remove — before this
change the agent also had to fetch the URL, check it, and possibly repair and
retry, each a further turn.

### Tasks 2.7 and 6.8 — the actual number

Re-run the task 1.5 loop with the measured grace value and compare against the
baseline. **This is the only figure that may be quoted as the speedup.** No
number appears in `SKILL.md`, `README.md`, or the PR description, and none should
until this exists.

Report separately:

- what the structural change bought (no second Chromium cold start; handoff can
  arm while the browser runs; re-auth without a shutdown),
- what tuning bought (grace window),
- what removing agent round-trips bought (from 1.6).

## 3. Log in — once

```bash
bash scripts/start_line_oa_chromium.sh
export LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login
bash scripts/start_line_oa_vnc_handoff.sh
```

The script prints one URL, already verified reachable. From here the boundary is
real:

- Send it **only** to the person logging in, in a direct private channel.
- Never log, paste into a ticket, reuse, or relay it.
- The moment they say login is done: `bash scripts/stop_line_oa_vnc_handoff.sh`.
  TTL expiry is a backstop, not a substitute.

```bash
bash scripts/doctor.sh    # expect exit 0
```

## 4. Task 6.3 — send after revocation

The point of attach mode: revoking the handoff did not kill the session.

```bash
bash scripts/run_line_oa_chat.sh --recipient "<real recipient>" --message "verification dry run"
```

`DRY-RUN OK` without restarting the browser is the result. No `--send`, so
nothing is transmitted.

Optionally confirm mid-session re-auth end to end: arm a second handoff on the
same session, revoke it, and dry-run again.

## Checklist

- [ ] 1.5 baseline recorded, 3 runs, `baseline.md`
- [ ] 1.7 grace sweep recorded; smallest reliable value chosen and applied
- [ ] 1.6 `T0`/`T1`/`T2` recorded once
- [ ] 2.7 post-change comparison against 1.5
- [ ] 6.3 dry run succeeds after revocation without a browser restart
- [ ] 6.8 speedup reported, split into structural / tuning / agent-turn parts

## If something fails

| Symptom | Cause |
| --- | --- |
| `No usable sandbox!` | `chromium-sandbox` not installed |
| `missing browser-session dependencies: ...` | Install the named packages; the message lists them all at once |
| `could not start private Xvfb display :99` | Display in use; set `LINE_OA_SEND_CHAT_XVFB_DISPLAY=:100` |
| `the profile is locked by host '<other>'` | Another Chromium may hold the profile. Verify before removing the lock — this is deliberately not automatic |
| `FAILED_dns_resolved` | Grace too short, or no outbound DNS |
| Tunnel URL emitted but never verifies | See `references/handoff-operations.md` |

Nothing prints a URL unless it verified. A non-zero exit means no handoff is
armed and everything it started was revoked.
