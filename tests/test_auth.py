import os
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import send_line_oa_chat as send
from playwright.sync_api import Error


class AutoLoginTests(unittest.TestCase):
    def test_rejects_untrusted_or_ambiguous_chat_urls(self):
        for url in ("http://chat.line.biz/Uabc", "https://chat.line.biz.evil/Uabc",
                    "https://user@chat.line.biz/Uabc", "https://chat.line.biz/Uabc?redirect=evil",
                    "https://chat.line.biz/", "https://chat.line.biz/Uabc#fragment"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                send.validate_chat_url(url)
        self.assertEqual(send.validate_chat_url("https://chat.line.biz/Uabc"), "https://chat.line.biz/Uabc")

    def test_valid_session_never_touches_credentials(self):
        page = MagicMock()
        page.url = "https://chat.line.biz/Uabc"
        with patch.dict(os.environ, {}, clear=True):
            send.ensure_chat_auth(page, "https://chat.line.biz/Uabc", True, 1000)
        page.goto.assert_called_once_with("https://chat.line.biz/Uabc", wait_until="domcontentloaded", timeout=1000)
        page.get_by_role.assert_not_called()

    def test_expired_session_requires_explicit_opt_in(self):
        page = MagicMock()
        page.url = "https://account.line.biz/login"
        with self.assertRaisesRegex(RuntimeError, "reauthentication required"):
            send.ensure_chat_auth(page, "https://chat.line.biz/Uabc", False, 1000)
        page.get_by_role.assert_not_called()

    def test_auto_login_refuses_missing_credentials_before_submit(self):
        page = MagicMock()
        page.url = "https://account.line.biz/login"
        with patch.dict(os.environ, {}, clear=True), self.assertRaisesRegex(RuntimeError, "credentials unavailable"):
            send.ensure_chat_auth(page, "https://chat.line.biz/Uabc", True, 1000)
        page.get_by_role.assert_not_called()

    def test_auto_login_fills_only_business_id_form_and_waits_for_target(self):
        page = MagicMock()
        page.url = "https://account.line.biz/login"
        credentials = {"LINE_OA_BUSINESS_EMAIL": "example@example.test", "LINE_OA_BUSINESS_PASSWORD": "secret-example"}
        with patch.dict(os.environ, credentials, clear=True):
            clicks = 0
            def after_click(**kwargs):
                nonlocal clicks
                clicks += 1
                if clicks == 2:
                    page.url = "https://chat.line.biz/Uabc"
            page.get_by_role.return_value.click.side_effect = after_click
            send.ensure_chat_auth(page, "https://chat.line.biz/Uabc", True, 1000)
        page.get_by_role.assert_any_call("button", name="Email address")
        page.get_by_role.assert_any_call("textbox", name="Log in with business account")
        page.get_by_role.assert_any_call("textbox", name="Password")
        page.get_by_role.assert_any_call("button", name="Log in", exact=True)
        page.get_by_role.return_value.fill.assert_any_call("example@example.test", timeout=1000)
        page.get_by_role.return_value.fill.assert_any_call("secret-example", timeout=1000)

    def test_unknown_login_destination_never_receives_password(self):
        page = MagicMock()
        page.url = "https://example.com/login"
        with patch.dict(os.environ, {"LINE_OA_BUSINESS_EMAIL": "e", "LINE_OA_BUSINESS_PASSWORD": "p"}, clear=True):
            with self.assertRaisesRegex(RuntimeError, "unexpected authentication destination"):
                send.ensure_chat_auth(page, "https://chat.line.biz/Uabc", True, 1000)
        page.get_by_role.assert_not_called()

    def test_fill_failure_does_not_leak_password(self):
        page = MagicMock()
        page.url = "https://account.line.biz/login"
        page.get_by_role.return_value.fill.side_effect = Error('fill("secret-example") failed')
        with patch.dict(os.environ, {"LINE_OA_BUSINESS_EMAIL": "e", "LINE_OA_BUSINESS_PASSWORD": "secret-example"}, clear=True):
            with self.assertRaises(RuntimeError) as caught:
                send.ensure_chat_auth(page, "https://chat.line.biz/Uabc", True, 1000)
        self.assertNotIn("secret-example", str(caught.exception))
        self.assertIsNone(caught.exception.__cause__)

    def test_login_checkpoint_does_not_proceed_to_send(self):
        page = MagicMock()
        page.url = "https://account.line.biz/login"
        with patch.dict(os.environ, {"LINE_OA_BUSINESS_EMAIL": "e", "LINE_OA_BUSINESS_PASSWORD": "p"}, clear=True):
            with self.assertRaisesRegex(RuntimeError, "manual authentication required"):
                send.ensure_chat_auth(page, "https://chat.line.biz/Uabc", True, 1000)
        page.get_by_placeholder.assert_not_called()


if __name__ == "__main__":
    unittest.main()
