# line-oa-chat-send

A reusable, safety-first CLI helper for sending messages through an already authenticated [LINE Official Account Chat](https://chat.line.biz/) browser session.

The command attaches to an existing local Chromium DevTools (CDP) endpoint. It does **not** start a second browser, log in to LINE, or collect credentials.

## What it does

- Searches for a chat recipient and refuses ambiguous matches.
- Opens the selected conversation and confirms that the message composer is available.
- Defaults to a no-send dry run.
- Requires an explicit `--send` flag before it can send a message.
- After a send, checks that the composer cleared and the exact message appears in the active chat transcript.

## Requirements

1. A user-authenticated LINE OA Chat session is open in Chromium.
2. Chromium exposes a local CDP endpoint (the default is `http://127.0.0.1:9222`).
3. Python with Playwright is available, and the matching Playwright browser files are installed.
4. The person running the command has explicit authorization for the recipient and outgoing message.

> **Authentication:** complete LINE login, password entry, QR confirmation, MFA, OTP, and security prompts yourself in the interactive browser. This project never accepts, stores, or transmits those secrets.

## Usage

Run the launcher from the repository root. It selects the dedicated LINE OA runtime, including the Python environment with Playwright and the matching browser cache. Do **not** invoke the system `python3` directly: it does not include Playwright in this environment.

```bash
# Safe default: find and open a uniquely matched chat, but do not send anything.
bash scripts/run_line_oa_chat.sh \
  --recipient "Recipient name" \
  --message "Message text"
```

To send a message, use `--send` **only** after the recipient and exact text have been explicitly authorized:

```bash
bash scripts/run_line_oa_chat.sh \
  --recipient "Recipient name" \
  --message "Message text" \
  --send
```

The launcher defaults to `/opt/data/.line-oa-automation`. To use an intentionally different runtime, set `LINE_OA_RUNTIME_ROOT`; `LINE_OA_PYTHON` and `PLAYWRIGHT_BROWSERS_PATH` are also available for advanced overrides.

View all options with:

```bash
bash scripts/run_line_oa_chat.sh --help
```

## Safety behavior

- A run without `--send` never transmits a message.
- If more than one chat may match the supplied recipient, the command stops instead of guessing.
- If the authenticated LINE UI, chat selection, composer, or post-send verification fails, the command exits non-zero.
- Do not retry a failed post-send verification automatically: LINE may have accepted the message even if verification did not complete.
- Keep the CDP endpoint local. Do not expose browser debugging ports, persistent profiles, cookies, screenshots, or VNC ports publicly.

## Testing

The command can be tested safely against an authenticated session with a dry run:

```bash
# Verify the implementation itself.
/opt/data/.line-oa-automation/venv/bin/python -m py_compile scripts/send_line_oa_chat.py

# Verify the shared runtime launcher and safely exercise the authenticated UI.
bash scripts/run_line_oa_chat.sh --help
bash scripts/run_line_oa_chat.sh \
  --recipient "Recipient name" \
  --message "CLI dry-run verification"
```

A successful dry run reports the selected chat and confirms that no message was sent.

## Skill documentation

See [SKILL.md](SKILL.md) for the complete automation procedure, authentication/session guidance, UI selector notes, and publishing workflow.
