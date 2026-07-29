## Why

`SKILL.md` is 18KB of mixed content: policy the agent must hold while deciding, step-by-step procedure that belongs in scripts, and reference material only needed when debugging the handoff infrastructure. Two of its links point at a `references/` directory that does not exist, and since the ClawHub workflow publishes the whole repository, those broken links ship to consumers. The inline Python reference implementation has already drifted from `scripts/send_line_oa_chat.py` — it omits the ambiguity check and the composer-cleared check — making it a second, wrong source of truth.

## What Changes

- Restructure `SKILL.md` around what the agent needs at decision time: when to use the skill, the security boundary, a short command-level quick start, and the conditions that require stopping and asking the user.
- Create the missing `references/` directory and its two referenced files, so no published link is broken:
  - `references/line-oa-ui-selectors.md` — the DOM patterns and responsive-layout behavior currently described inline.
  - `references/public-repository-checklist.md` — the repository-publication audit sequence currently described inline.
- Add `references/handoff-operations.md` and move the infrastructure debugging pitfalls into it (Caddy site address, x11vnc flags, port assumptions, local-curl-is-not-verification). These are only needed when modifying the handoff scripts, and most are already enforced in code.
- Remove the inline Python reference implementation. `scripts/send_line_oa_chat.py` is the single source of truth.
- Move the "Publishing updates" and "Making the repository public" sections to `CONTRIBUTING.md`. This is the repository's own development process, not knowledge an agent needs in order to send a message.
- Convert the prose environment-preflight procedure into `scripts/doctor.sh`, reducing the `SKILL.md` section to a single command with a description of what a failure means.
- Reduce the shutdown section to the scripted shutdown introduced by `speed-up-login-handoff`.
- Update `README.md` for the same command surface, so the two documents do not disagree.

## Capabilities

### New Capabilities
- `skill-documentation`: what `SKILL.md` and its reference material must contain, what must live outside it, and the consistency rules between documentation and the scripts it describes.
- `environment-preflight`: a scripted check that reports whether the runtime, browser, display, and handoff dependencies are usable, replacing the prose procedure.

### Modified Capabilities
<!-- No existing specs in openspec/specs/ yet; both capabilities above are new. -->

## Impact

- `SKILL.md` — substantial restructure and size reduction.
- `README.md` — aligned with the new command surface.
- New `references/` directory with three files.
- New `CONTRIBUTING.md`.
- New `scripts/doctor.sh`.
- Depends on `speed-up-login-handoff`. That change alters the operator sequence, the script names, and removes the agent-performed URL verification that `SKILL.md` currently mandates. Documenting the current behavior first would mean rewriting it twice, so this change lands after it.
- No change to messaging behavior, network exposure, or the security boundary itself. The security boundary text is preserved in full; only its location and surrounding material change.
