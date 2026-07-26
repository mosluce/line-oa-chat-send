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
2. Provide the user with a temporary, protected interactive browser session. The preferred setup is a headed Chromium inside a virtual display, with VNC exposed only through a local-only VNC server plus protected noVNC/tunnel access. Never expose raw VNC port `5900` to the public internet.
3. The user completes LINE authentication themselves in that browser session, including password, QR confirmation, MFA, OTP, security prompts, and recovery flows. Do not request, read, type, store, relay, or log any credentials or verification codes.
4. After the user says login is complete, inspect the existing browser page. Authentication is ready only when a `https://chat.line.biz/` page loads the authenticated chat UI rather than a sign-in, expired-session, or access-denied screen.
5. Reuse the same persistent profile for subsequent sends. If LINE expires or revokes the session, pause the task and ask the user to reauthenticate through the protected interactive browser; then repeat the authenticated-UI check.

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

recipient = "默司"
message = "測試訊息"
with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp("http://127.0.0.1:9222")
    page = next(pg for ctx in browser.contexts for pg in ctx.pages
                if pg.url.startswith("https://chat.line.biz/"))
    search = page.get_by_placeholder("搜尋")
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

## Pitfalls
- `get_by_text(recipient, exact=True)` may target the signed-in account menu instead of the chat result when names collide.
- On a narrow layout the matching chat label may have no bounding box because the sidebar hides text, while its containing chat-list `<a>` is still clickable. Locate the anchor from the matching `<mark>` instead of treating a hidden label as a failed search.
- `get_by_placeholder(...)` can match both the custom `textarea-ex` host and its internal textarea. Use `textarea-ex >> textarea` / chained locators so Playwright targets the true editable element.
- A successful click alone is not sufficient; always verify the exact outgoing text in the active transcript after submission, preferably in the recent transcript tail rather than via a broad page-wide match.
- If the recipient search yields more than one distinct chat, stop and ask the user which conversation to use.
- Never request, handle, record, or transmit LINE passwords, OTPs, or other credentials.
