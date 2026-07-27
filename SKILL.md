---
name: line-oa-chat-send
description: Send and verify a LINE Official Account Chat message through an already authenticated persistent Chromium session.
---

# LINE OA Chat: send a message

## Use when
A user provides or has already opened a LINE OA Chat URL and asks to send a specific message to a named chat recipient.

## Prerequisites
- The persistent Chromium profile is already authenticated to LINE OA by the user.
- Chromium is available via its local CDP endpoint (normally `http://127.0.0.1:9222`).
- The user has explicitly authorized the outgoing message. Do not infer a message other than an unambiguous test message.

## Authentication and session setup
1. Run Chromium with a dedicated persistent `--user-data-dir` owned only by the automation service. Do not use an ephemeral browser profile; the user’s LINE OA session and cookies must survive later message runs.
2. Provide the user with a temporary, protected interactive browser session. Run `bash scripts/start_line_oa_vnc_handoff.sh` when no authenticated profile exists. It starts headed Chromium, loopback-only VNC/noVNC, a high-entropy private Caddy path, and a temporary Cloudflare Quick Tunnel, then emits one HTTPS noVNC URL. Share that bearer URL only with the intended user in the DM; never log, commit, or reuse it. Raw VNC `5900` and CDP remain loopback-only. The user directly clicks, types, pastes, and scrolls in noVNC.
3. The user completes LINE authentication themselves in that browser session, including password, QR confirmation, MFA, OTP, security prompts, and recovery flows. Do not request, read, type, store, relay, or log any credentials or verification codes.
4. After the user says login is complete, inspect the existing browser page. Authentication is ready only when a `https://chat.line.biz/` page loads the authenticated chat UI rather than a sign-in, expired-session, or access-denied screen.
5. Reuse the same persistent profile for subsequent sends. If LINE expires or revokes the session, pause the task and ask the user to reauthenticate through the protected interactive browser; then repeat the authenticated-UI check.

## Starting Chromium and CDP
When the CDP endpoint is unavailable, start **one** headed Chromium. Its persistent profile path is selected by `LINE_OA_SEND_CHAT_CHROMIUM_PROFILE`, falling back to `/opt/data/chromium`; the startup helper creates that directory with permission mode `700` when it is absent.

1. Ensure a protected headed display already exists (`DISPLAY` or `--display`). The profile contains retained LINE session data: never commit, copy, inspect, or disclose it. A newly created fallback profile is not logged in, so the user must authenticate through the protected GUI before any send.
2. Select the Chromium executable explicitly with `LINE_OA_CHROMIUM` / `--chromium`, or let the startup script discover a system Chromium command.
3. Start the foreground process through a supervisor or tracked background process:
   ```bash
   export LINE_OA_SEND_CHAT_CHROMIUM_PROFILE="/private/operator-chosen/chrome-profile"  # optional; default: /opt/data/chromium
   export LINE_OA_CHROMIUM="/path/to/chromium"  # optional when Chromium is on PATH
   bash scripts/start_line_oa_chromium.sh
   ```
   `--profile-dir` can override the environment-selected profile for one invocation. The script binds CDP only to `127.0.0.1:9222`, refuses to start if that endpoint already responds, and opens `https://chat.line.biz/`. It does not log in or expose VNC/CDP publicly.
4. Confirm CDP is live before using the send CLI:
   ```bash
   curl --max-time 3 -fsS http://127.0.0.1:9222/json/version >/dev/null
   ```
   Then inspect the existing LINE OA page. If LINE requires login, QR, MFA, OTP, or a challenge, only the user may resolve it through the protected GUI.

## Shutdown after use
When the user says the LINE OA work is finished, close Chromium to release server resources while preserving the private persistent profile for later reuse.

1. Confirm no send, dry-run, setup, or user GUI interaction is active. If an unfinished composer draft or another user session may be open, ask before closing.
2. Identify exactly one operator-owned Chromium root process through its configured local CDP endpoint or service supervisor. Do not rely on a fixed binary path, profile path, PID, or a broad `pkill` pattern.
3. Send the root process a graceful termination signal (`SIGTERM`) and allow it time to exit. Do not delete, copy, inspect, or modify the persistent browser profile; it contains the retained session.
4. Verify the local CDP endpoint is unreachable and Chromium browser/renderer processes have exited. A crash-report helper may remain briefly and does not retain the browser session.
5. If the browser does not exit after the graceful timeout, report the blocker and wait for user direction before using a forced kill. Shut down any protected VNC/noVNC/tunnel components separately only when they exist solely for this browser and are no longer needed.

A later start with the same private persistent profile will usually retain LINE login, but LINE may still expire or revoke the session and require user reauthentication through the protected GUI.

## Environment preflight and safe provisioning
Before reporting that the environment is unavailable, **the agent must inspect and prepare it itself**. Do not merely ask the operator to install a missing Python package, browser, profile directory, or display when the following safe steps can resolve it.

1. Select a private runtime directory from `LINE_OA_SEND_CHAT_RUNTIME_DIR`, or use `${XDG_STATE_HOME:-$HOME/.local/state}/line-oa-chat-send`. This is runtime/cache data only; never place it inside the Chromium profile or Git repository.
2. If Playwright, its managed Chromium, or the selected runtime is absent, provision all three in one command:
   ```bash
   runtime_dir="${LINE_OA_SEND_CHAT_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/line-oa-chat-send}"
   bash scripts/setup_line_oa_runtime.sh --runtime-dir "$runtime_dir"
   export LINE_OA_PYTHON="$runtime_dir/venv/bin/python"
   export LINE_OA_SEND_CHAT_BROWSER_DIR="$runtime_dir/ms-playwright"
   ```
   The setup script creates private `700` directories, installs the Python Playwright dependency, and downloads its managed Chromium into the private runtime. It never reads a browser profile or handles LINE credentials. Use `--skip-browser-install` only for a client-only/CDP test that will not launch Chromium.
3. Run `scripts/start_line_oa_chromium.sh`. It creates the selected profile directory when absent and, if `DISPLAY` is missing, starts a private local `Xvfb` display for the lifetime of its Chromium child. It does **not** expose VNC, noVNC, CDP, or a GUI to the network. A protected GUI-sharing service remains an operator-controlled prerequisite for user login.
4. If `uv`, `Xvfb`, or a VNC/noVNC handoff dependency is missing, report the exact missing commands and print the apt install command for an operator with host package permission. The skill must not invoke `sudo`, `apt-get`, or another system package manager itself. Never weaken network bindings.
5. After provisioning, health-check CDP and inspect the LINE page. A new profile will require the user to authenticate through the protected GUI; this is a security checkpoint, not an install failure.

Do **not** assume a particular home directory, virtual environment, browser cache, or runtime folder exists. For browser-profile selection specifically, use `LINE_OA_SEND_CHAT_CHROMIUM_PROFILE` or its explicit fallback `/opt/data/chromium` as described above. The runtime requirements are: (1) a Python environment containing the `playwright` package and (2) an already-running, user-authenticated Chromium reachable through a local CDP endpoint. Connecting over CDP does not require Playwright to download or launch another browser.

The portable launcher still honors an explicit `LINE_OA_PYTHON`, then any current Python that imports Playwright, then `uv run --with playwright`. It connects only to an existing CDP browser; it does not log in or accept credentials.

## CLI script
Use `scripts/run_line_oa_chat.sh` rather than invoking `python scripts/send_line_oa_chat.py` directly. It connects only to an already-running local CDP endpoint; it does not perform login or accept credentials.

```bash
# Safe default: find and open the uniquely matched chat, but do not send.
bash scripts/run_line_oa_chat.sh \
  --recipient "<exact recipient>" --message "<message>"

# Send only after the user explicitly authorizes this exact recipient and message.
bash scripts/run_line_oa_chat.sh \
  --recipient "<exact recipient>" --message "<message>" --send
```

The script refuses ambiguous recipient results, requires `--send` for the external side effect, and exits non-zero when session/UI verification fails. After sending, it verifies that the composer cleared and the exact text appeared in the active transcript. Do not retry a failed verification until the protected browser is inspected, because LINE may already have accepted the message.

## Procedure
1. Connect with Playwright's sync API over CDP. Inspect all open pages and select the page whose URL begins with `https://chat.line.biz/`.
2. Inspect the chat page before acting. Use the sidebar input with `aria-label="搜尋"` / placeholder `搜尋` to search the requested recipient.
3. Select the result from the chat list, not a same-named account/profile menu item. In this UI the searchable chat's text can be inside a `<mark>` and its clickable parent is an ancestor `<a>`.
4. Confirm the selected conversation has loaded by checking that the message composer and prior conversation content are visible.
5. Fill the actual composer inside LINE's custom element using the shadow-DOM-piercing locator `page.locator('textarea-ex').locator('textarea')`, then click `input[type="submit"][value="傳送"]`.
6. Wait for UI update and verify the exact message appears in the active chat transcript. Report only after this verification succeeds.

## Reference implementation
```python
from playwright.sync_api import sync_playwright

recipient = "<exact recipient>"
message = "<message>"
with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp("http://127.0.0.1:9222")
    page = next(pg for ctx in browser.contexts for pg in ctx.pages
                if pg.url.startswith("https://chat.line.biz/"))
    search = page.get_by_placeholder("搜尋", exact=True)
    search.fill(recipient)
    page.wait_for_timeout(800)
    chat = page.locator("mark").filter(has_text=recipient).first.locator("xpath=ancestor::a")
    chat.click()
    page.locator("textarea-ex").locator("textarea").fill(message)
    page.locator('input[type="submit"][value="傳送"]').click()
    page.wait_for_timeout(1200)
    assert message in page.locator("body").inner_text()
```

## UI reference
See [LINE OA UI selector notes](references/line-oa-ui-selectors.md) for the current DOM patterns and responsive-layout behavior observed in the web client.

## Publishing updates
When changing this skill in its GitHub repository, use the normal Git/PR lifecycle rather than committing to `main` directly.

### Making the repository public
Use [the public repository checklist](references/public-repository-checklist.md) for the full audit, settings, and verification sequence.

Before changing visibility, audit **all reachable Git history**, not only the current files: old commits and merged PRs remain visible after publication. Scan for credentials, authentication headers, tunnel/share URLs, browser-profile data, and host-specific runtime paths, reporting only commit IDs and pattern categories—not matched secret values. Remove or rewrite genuinely sensitive history before publication.

Apply public-facing settings before changing visibility: remove unused collaboration surfaces, enable automatic deletion of merged branches, and disable unused Actions until a reviewed workflow exists. After changing visibility, verify the repository and README through an unauthenticated request, then enable supported public-repository security controls (secret scanning, push protection, Dependabot). GitHub may automatically enable or reject some settings for public repositories, so read back the resulting state. Treat LICENSE selection as a separate legal decision; do not choose one without the user’s direction.

1. Run `gh auth status` in the same OS user and runtime that will run Git/`gh` commands. A GitHub browser session or CLI login in another shell/user does not authenticate this runtime.
2. If CLI auth is missing, start the browser/device flow with `gh auth login --hostname github.com --git-protocol https --web`. When the user asks to “just run it and give me the code,” run the flow directly and reply only with the generated one-time device code plus `https://github.com/login/device`; do not add extra explanation. Wait for their authorization, then verify with `gh auth status` before proceeding.
3. Start from the current `main` branch and create a focused branch such as `docs/update-authentication`.
4. Validate the edited `SKILL.md`, commit the change, and push the branch.
5. Use GitHub CLI (`gh pr create`) to open a PR that summarizes the change and its verification.
6. Test the exact remote PR revision before reporting it: obtain `headRefOid` with `gh pr view <number> --json headRefOid`, then check out that SHA in a clean worktree and run Python compilation, `--help`, and a no-send dry-run against the authenticated LINE UI. If a shallow clone has a restrictive fetch refspec and `gh pr checkout` cannot set tracking for the PR branch, create a local non-tracking branch at the verified `headRefOid` (for example, `git switch -c pr-<number> <sha>`). Do not test an unverified local copy instead.
7. Treat documentation-only changes (including README updates) as repository changes too: branch, validate, push, open a PR, and leave it unmerged for review.
8. Merge only after the user explicitly approves it. A concise `merge` instruction is sufficient authorization; use a squash merge and delete the feature branch, then verify the PR state and remote branch deletion with `gh`.

## Pitfalls
- `get_by_text(recipient, exact=True)` may target the signed-in account menu instead of the chat result when names collide.
- On a narrow layout the matching chat label may have no bounding box because the sidebar hides text, while its containing chat-list `<a>` is still clickable. Locate the anchor from the matching `<mark>` instead of treating a hidden label as a failed search.
- Playwright placeholder matching is substring-based by default. Use `page.get_by_placeholder("搜尋", exact=True)` so the chat-list search does not also match LINE's unrelated `輸入搜尋內容` field.
- `get_by_placeholder(...)` can match both the custom `textarea-ex` host and its internal textarea. Use `textarea-ex >> textarea` / chained locators so Playwright targets the true editable element.
- A successful click alone is not sufficient; always verify the exact outgoing text in the active transcript after submission, preferably in the recent transcript tail rather than via a broad page-wide match.
- If the recipient search yields more than one distinct chat, stop and ask the user which conversation to use.
- Never request, handle, record, or transmit LINE passwords, OTPs, or other credentials.
