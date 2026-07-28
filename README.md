# line-oa-chat-send

A reusable, safety-first CLI helper for sending messages through an already authenticated [LINE Official Account Chat](https://chat.line.biz/) browser session.

The command attaches to an existing local Chromium DevTools (CDP) endpoint. It does **not** start a second browser, log in to LINE, or collect credentials.

> **Optional login handoff — high-risk capability:** If a user explicitly asks to complete LINE login or reauthentication through a remote GUI, this repository also provides `scripts/start_line_oa_vnc_handoff.sh`. It creates a temporary Cloudflare noVNC URL that grants its holder interactive control of the browser. It is not used for ordinary messaging, browsing, or autonomous actions. The script requires the explicit `LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login` scope, defaults to a 15-minute TTL, keeps VNC and CDP loopback-only, and must be stopped immediately when login ends.

## What it does

- Searches for a chat recipient and refuses ambiguous matches.
- Opens the selected conversation and confirms that the message composer is available.
- Defaults to a no-send dry run.
- Requires an explicit `--send` flag before it can send a message.
- After a send, checks that the composer cleared and the exact message appears in the active chat transcript.

## Requirements

1. A user-authenticated LINE OA Chat session is open in Chromium.
2. Chromium exposes a local CDP endpoint (the default is `http://127.0.0.1:9222`).
3. Python with the `playwright` package is available. Browser downloads are not required because this tool attaches to an existing Chromium over CDP.
4. The person running the command has explicit authorization for the recipient and outgoing message.

> **Authentication:** complete LINE login, password entry, QR confirmation, MFA, OTP, and security prompts yourself in the interactive browser. This project never accepts, stores, or transmits those secrets.

## Environment setup

No runtime directory is assumed. The launcher checks an explicit `LINE_OA_PYTHON`, then current `python3`/`python`, and finally uses `uv run --with playwright` when `uv` is installed.

If none is available, provision a private runtime in an explicit location chosen by the operator:

```bash
bash scripts/setup_line_oa_runtime.sh --runtime-dir "$HOME/.local/share/line-oa-chat-runtime"
export LINE_OA_PYTHON="$HOME/.local/share/line-oa-chat-runtime/venv/bin/python"
```

The path above is an example only. The setup script never creates or accesses a browser profile, never opens a login flow, and never handles credentials. If CDP is unavailable, start one headed Chromium with a private profile and loopback-only CDP endpoint, then have the user log in through a protected interactive GUI. Do not start a second browser against an existing profile.

## Login / reauthentication handoff

Use this only after the user explicitly requests an interactive LINE login or reauthentication session. It is a login-only capability; do not use it to send messages or for unrelated browser control.

```bash
export LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login
export LINE_OA_SEND_CHAT_HANDOFF_TTL_SECONDS=900  # optional; allowed range 60–3600
bash scripts/start_line_oa_vnc_handoff.sh
```

The printed URL is a bearer secret. Share it only with that user in a private channel, do not log or reuse it, and stop the process immediately after they finish login. TTL expiry is a backstop, not a replacement for prompt revocation.

## Usage

Run the launcher from the repository root:

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

Use `--cdp-url` if the local endpoint is not the default. View all options with:

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
# Direct Python reports a concrete recovery instruction when Playwright is missing.
python3 scripts/send_line_oa_chat.py --help

# The portable launcher selects or provisions a valid Python runtime.
bash scripts/run_line_oa_chat.sh --help
bash scripts/run_line_oa_chat.sh \
  --recipient "Recipient name" \
  --message "CLI dry-run verification"
```

A successful dry run reports the selected chat and confirms that no message was sent.

## Skill documentation

See [SKILL.md](SKILL.md) for the complete automation procedure, authentication/session guidance, UI selector notes, and publishing workflow.
