## Context

`SKILL.md` currently carries three kinds of content with no separation:

1. **Decision knowledge** — the security boundary, when the skill applies, when to stop and ask the user. The agent must hold this in context to act correctly.
2. **Procedure** — environment preflight (5 steps plus 2 paragraphs), shutdown (5 steps), handoff startup and verification (one very long paragraph). This is deterministic and belongs in scripts; leaving it as prose forces the agent to improvise a fixed sequence on every run.
3. **Reference material** — infrastructure pitfalls, DOM selector notes, repository publication process. Needed only when debugging or when working on the repository itself.

Category 2 is the expensive one. The handoff paragraph in particular makes the agent fetch the public URL, check for `noVNC`, and on failure revoke, repair, and regenerate — each step a separate agent turn. `speed-up-login-handoff` moves that verification into the script, which is what makes this restructure possible rather than merely tidy.

Two `references/` links are already broken, and ClawHub publishes with `skill publish .`, so consumers receive them broken.

The inline Python reference implementation duplicates `scripts/send_line_oa_chat.py` and has drifted: it lacks the unique-match check and the composer-cleared check, and verifies with a bare `assert message in body`. An agent that follows it instead of the CLI gets weaker safety than the CLI provides.

## Goals / Non-Goals

**Goals:**

- Reduce what the agent must read before it can act, without weakening any safety rule.
- Eliminate second sources of truth: one implementation, one command surface, one description of each procedure.
- Ship no broken links.
- Keep deep material available on demand rather than deleting it.

**Non-Goals:**

- Weakening or shortening the security boundary. It is preserved in full.
- Changing messaging, matching, or network exposure behavior.
- Documenting the pre-`speed-up-login-handoff` operator sequence.
- Non-Linux instructions.

## Decisions

### Split by "needed to decide" versus "needed to do" versus "needed to debug"

`SKILL.md` keeps only category 1 plus a command-level quick start. Category 2 becomes scripts. Category 3 moves to `references/`.

Target shape:

```
SKILL.md
├─ Use when
├─ Security boundary            (preserved in full)
├─ Quick start                  (doctor / handoff / send / stop)
├─ When to stop and ask the user
└─ Pointers into references/

references/
├─ line-oa-ui-selectors.md
├─ handoff-operations.md
└─ public-repository-checklist.md

CONTRIBUTING.md
scripts/doctor.sh
```

Because ClawHub publishes the whole repository, `references/` ships with the skill and stays loadable on demand. Moving material there removes it from the default context without removing it from the package.

Alternative considered: keeping everything inline and only fixing the broken links. Rejected — it leaves the agent reading the repository's own PR workflow in order to send a message.

### The security boundary stays in `SKILL.md`, in full

It is the one section that must be in context at decision time. Size reduction elsewhere is not a reason to compress it, and it is not moved to `references/`.

### Delete the inline Python reference implementation outright

Not moved to `references/` — a drifted duplicate is worse in a reference file than in the main document, because it looks authoritative and is consulted precisely when someone is debugging. `scripts/send_line_oa_chat.py` is the single source of truth; `references/line-oa-ui-selectors.md` documents the selectors and the reasoning behind them without restating the algorithm.

### Pitfalls are split by audience, not kept as one list

Of the current eleven pitfalls, roughly five concern handoff infrastructure (Caddy host-agnostic site address, x11vnc `-noxrecord -noxfixes -noxdamage`, never assuming ports 5900/6080 are free, local curl being insufficient verification). These are already enforced in the scripts, so their remaining value is explaining *why* the code looks the way it does — which matters when editing the scripts, not when sending a message. They move to `references/handoff-operations.md`.

The pitfalls that constrain agent behavior at run time — refuse ambiguous recipients, never retry a failed post-send verification, never handle credentials — stay in `SKILL.md` under the stop-and-ask section, because they are decision rules, not trivia.

### Preflight becomes a script that reports a verdict, not steps to follow

`scripts/doctor.sh` checks the Python/Playwright runtime, the Chromium binary, the profile directory, the display, the CDP endpoint, and the handoff dependencies, then reports each as usable or not with a concrete remediation for each failure. It performs no privileged installation and invokes no system package manager, matching the existing constraint.

The distinction the current prose draws — that a new, unauthenticated profile is a security checkpoint rather than an install failure — is preserved as a distinct verdict, so the agent does not report a missing login as a broken environment.

Alternative considered: leaving preflight as prose since it is mostly conditional. Rejected — the conditionals are exactly what an agent gets wrong under time pressure, and they are cheap to encode.

### `README.md` and `SKILL.md` are kept consistent by construction

Both describe the same command surface. `README.md` addresses a human evaluating or operating the tool; `SKILL.md` addresses an agent executing it. Neither restates the other's procedure, and the command names and flags are identical in both.

## Risks / Trade-offs

- **Moving material to `references/` makes it easier to overlook** → `SKILL.md` names each reference file and states when to read it, and everything ships in the same published package.
- **Trimming could drop a safety rule by accident** → Every removed line is classified before removal: kept, moved to a named reference, encoded in a script, or deleted as a duplicate. Deletion is only used for duplicated content, and the security boundary is exempt from reduction.
- **This change depends on `speed-up-login-handoff` and could drift if that change is revised** → The dependency is one-directional and stated in the proposal. `speed-up-login-handoff` ends by recording the new operator sequence and script names for this change to consume, so the two do not need to be re-derived independently.
- **`doctor.sh` gives a false sense of readiness if a check is superficial** → Checks assert the actual capability (CDP responds, Chromium is executable, the profile directory is writable), not merely that a command exists on `PATH`.
- **Removing the inline Python example removes a quick way to understand the flow** → `references/line-oa-ui-selectors.md` covers the selectors and reasoning, and the CLI is a short, readable file.

## Open Questions

- ~~Does anything consuming the published ClawHub skill depend on the current `SKILL.md` section headings?~~ **Resolved: no.** The workflow publishes the whole tree with `skill publish .`, and the only structured fields are the frontmatter `name` and `description`, both unchanged. Nothing in the repository links to a `SKILL.md` heading anchor, and headings are not a machine-readable contract. No release compatibility note is needed.
