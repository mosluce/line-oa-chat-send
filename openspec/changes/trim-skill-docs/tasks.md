## 1. Classify before cutting

- [ ] 1.1 Confirm `speed-up-login-handoff` has landed and read its task 7 output: the invalidated statements and the new operator sequence and script names
- [ ] 1.2 Walk every section of `SKILL.md` and label each as keep in place, move to a named reference file, encode in a script, or delete as a duplicate
- [ ] 1.3 Record the classification in the change directory so no line is removed without a destination
- [ ] 1.4 Verify the security boundary is labelled keep-in-place in its entirety, with no line marked for reduction

## 2. Scripted preflight

- [ ] 2.1 Create `scripts/doctor.sh` checking the Python/Playwright runtime, Chromium executable, profile directory, display, CDP endpoint, and handoff dependencies
- [ ] 2.2 Assert real capability in each check: import Playwright, executable bit, writable directory, endpoint responds — not command presence alone
- [ ] 2.3 Report a distinct verdict for "environment usable, LINE session absent or expired" that is not an environment failure
- [ ] 2.4 Print concrete remediation per failing check, invoking no `sudo` and no system package manager, and never suggesting a widened network binding
- [ ] 2.5 Exit zero only when the environment can perform a message send
- [ ] 2.6 Verify against a healthy environment, a missing-runtime environment, a missing-handoff-dependency environment, and an unauthenticated-profile environment. These four are provided by `add-container-test-env` as the `full`, `no-runtime`, `no-handoff-deps`, and `unauth-profile` variants; run via `containers/run.sh <variant>` and add the verdict assertions to `containers/test/default.sh`

## 3. Populate references/

- [ ] 3.1 Create `references/line-oa-ui-selectors.md` from the inline UI selector notes, documenting the selectors and the reasoning without restating the send algorithm
- [ ] 3.2 Create `references/handoff-operations.md` and move the infrastructure pitfalls into it: Caddy host-agnostic site address, x11vnc flag rationale, dynamic port selection, local-curl-is-not-verification
- [ ] 3.3 Create `references/public-repository-checklist.md` from the inline repository-publication audit sequence
- [ ] 3.4 Confirm each file explains why the scripts look the way they do, rather than duplicating what the scripts already enforce

## 4. Move development process out of the skill

- [ ] 4.1 Create `CONTRIBUTING.md` and move the "Publishing updates" and "Making the repository public" sections into it
- [ ] 4.2 Update `CONTRIBUTING.md` for the current repository state, including the ClawHub tag-publish workflow
- [ ] 4.3 Remove both sections from `SKILL.md`

## 5. Restructure SKILL.md

- [ ] 5.1 Rewrite to the target shape: Use when, Security boundary, Quick start, When to stop and ask the user, pointers into `references/`
- [ ] 5.2 Carry the security boundary across unchanged and diff it against the original to prove nothing was dropped
- [ ] 5.3 Write the Quick start against the post-`speed-up-login-handoff` command surface: preflight, arm handoff, send, stop session
- [ ] 5.4 State the run-time decision rules: refuse ambiguous recipients, never retry a failed post-send verification, never handle credentials
- [ ] 5.5 Delete the inline Python reference implementation
- [ ] 5.6 Delete the prose preflight and shutdown procedures, replacing each with its command
- [ ] 5.7 Remove the agent-performed URL verification instructions now enforced by the handoff script
- [ ] 5.8 Name each reference file and state when to read it

## 6. Align README.md

- [ ] 6.1 Update the command surface to match `SKILL.md` exactly, including script names and flags
- [ ] 6.2 Update the login handoff section for attach-mode behavior and script-side verification
- [ ] 6.3 Remove any operator sequence the scripts no longer implement
- [ ] 6.4 Confirm neither document restates the other's procedure

## 7. Verification

- [ ] 7.1 Check every relative link in `SKILL.md`, `README.md`, and `CONTRIBUTING.md` resolves to an existing file
- [ ] 7.2 Confirm the classification from 1.3 accounts for every removed line, with no line deleted without a destination
- [ ] 7.3 Confirm no document contains a runnable send implementation other than `scripts/send_line_oa_chat.py`
- [ ] 7.4 Confirm the security-boundary diff from 5.2 shows no constraint lost
- [ ] 7.5 Confirm no document describes the pre-`speed-up-login-handoff` sequence
- [ ] 7.6 Package the repository as the ClawHub workflow does and confirm the published tree contains `references/` with no broken links
- [ ] 7.7 Record the `SKILL.md` size before and after
- [ ] 7.8 Resolve the open question on whether any consumer depends on the current `SKILL.md` headings, and add a release compatibility note if so
