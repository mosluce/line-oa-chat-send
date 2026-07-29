# `SKILL.md` line classification

Every section of the 160-line original, labelled before anything is cut. Four
destinations only: **KEEP** in `SKILL.md`, **MOVE** to a named file, **SCRIPT**
(encoded in code, reduced to a command), or **DELETE** (duplicated content only).

Nothing is labelled DELETE unless the same content exists elsewhere and is
authoritative there.

| Lines | Section | Destination | Note |
| --- | --- | --- | --- |
| 1–4 | Frontmatter | KEEP | `description` updated: the handoff attaches to a session |
| 6–9 | Title, Use when | KEEP | Decision knowledge |
| 11–14 | Prerequisites | KEEP | Reworded against the new command surface |
| 16–19 | Security boundary | **KEEP IN FULL** | See the exemption below |
| 21–32 | Authentication and session setup | SCRIPT + KEEP | Steps 1/3/4/5 are policy → keep, compressed. Step 2's launch-and-verify paragraph → the script does it |
| 34–50 | Starting Chromium and CDP | SCRIPT | Becomes `start_line_oa_chromium.sh` plus what a failure means |
| 52–61 | Shutdown after use | SCRIPT | Becomes `stop_line_oa_chromium.sh`; the 5 prose steps are its implementation |
| 63–81 | Environment preflight and safe provisioning | SCRIPT | Becomes `doctor.sh`; the "new profile is a checkpoint, not a failure" distinction survives as a verdict |
| 83–96 | CLI script | KEEP | Shortened into Quick start; the safety sentences move to decision rules |
| 98–105 | Procedure | MOVE → `references/line-oa-ui-selectors.md` | Duplicates what the CLI does; the selector reasoning is the part worth keeping |
| 107–125 | Reference implementation (Python) | **DELETE** | Duplicate of `scripts/send_line_oa_chat.py`, and drifted: no unique-match check, no composer-cleared check, bare `assert message in body`. The CLI is authoritative |
| 127–128 | UI reference | KEEP as pointer | Target file now exists |
| 130–138 | Publishing updates / Making the repository public | MOVE → `CONTRIBUTING.md` + `references/public-repository-checklist.md` | Repository process, not skill knowledge |
| 140–147 | Publishing steps 1–8 | MOVE → `CONTRIBUTING.md` | Same |
| 149–156 | Pitfalls (behavioral) | KEEP | Become "When to stop and ask" decision rules |
| 157–159 | Pitfalls (handoff infrastructure) | MOVE → `references/handoff-operations.md` | Already enforced in code; the reasoning explains why the code looks that way |

## Security boundary exemption

Lines 16–19 are carried across verbatim in substance. Size reduction elsewhere
is not a reason to compress them, and they are not moved to `references/`.
Task 5.2 diffs the result against the original to prove no constraint was lost.

Every constraint that must survive:

1. Normal message work uses local CDP only; it exposes no browser, CDP, VNC,
   screenshots, cookies, or profile data to the network.
2. The handoff is **only** for user login/reauthentication.
3. It grants whoever holds the URL interactive control of the browser.
4. The URL is a high-risk bearer secret, not a general browsing or support
   channel.
5. Start one only after the user explicitly requests this route.
6. Default 15-minute TTL, configurable only within 60–3600 seconds.
7. Share only in a direct private channel.
8. Revoke immediately after login; TTL is a backstop, not a substitute.
9. Never use it to send messages, browse unrelated sites, or act autonomously.
10. Never log, commit, reuse, or relay the URL.

## Behavioral pitfalls that stay as decision rules

- `get_by_text(recipient, exact=True)` can hit the account menu instead of the
  chat result — the reason the CLI exists; stated as "use the CLI".
- Ambiguous recipient search → stop and ask which conversation.
- A successful click is not proof; verify the exact text in the transcript.
- Never retry a failed post-send verification without inspecting the browser.
- Never request, handle, record, or transmit LINE credentials.

## Statements deleted as newly false

Sourced from `speed-up-login-handoff/docs-handoff.md`, which lists nine
`SKILL.md` statements and three `README.md` statements invalidated by attach
mode. Those are removed rather than reworded where the replacement is a command.
