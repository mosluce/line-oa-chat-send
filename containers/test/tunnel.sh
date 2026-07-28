#!/usr/bin/env bash
# Opt-in tunnel test. NOT part of the default test path.
#
# This is the only test that makes anything externally reachable. It starts a
# real Cloudflare Quick Tunnel, so for the life of the tunnel a browser is
# reachable by anyone holding the URL. The container holds no LINE session, so
# what is exposed is a blank LINE login page -- but the exposure is real, which
# is why running it requires an explicit opt-in.
#
#   LINE_OA_TEST_ALLOW_TUNNEL=1 containers/test/tunnel.sh [ttl-seconds]
#
# Exposure is bounded three ways: the handoff's own TTL (default 60s here, the
# minimum the script accepts), the container's lifetime, and --rm on teardown.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
ttl="${1:-60}"

if [[ "${LINE_OA_TEST_ALLOW_TUNNEL:-}" != "1" ]]; then
  cat >&2 <<EOF
ERROR: this test makes a browser externally reachable and is opt-in.

  It starts a real Cloudflare Quick Tunnel. Anyone holding the emitted URL gets
  interactive control of the container's browser until the tunnel is revoked.
  The container has no LINE session, so the exposed page is a login screen.

  To run it anyway:
    LINE_OA_TEST_ALLOW_TUNNEL=1 containers/test/tunnel.sh [ttl-seconds]
EOF
  exit 2
fi

[[ "$ttl" =~ ^[0-9]+$ ]] && (( ttl >= 60 && ttl <= 3600 )) || {
  printf 'ERROR: ttl must be an integer from 60 to 3600 (got %s)\n' "$ttl" >&2
  exit 2
}

printf 'Starting an externally reachable handoff for %ss.\n' "$ttl"
printf 'The URL below is a bearer secret; it is printed here only because this\n'
printf 'container holds no session. Do not reuse this path for a real profile.\n\n'

# NOTE: this drives the handoff as it exists today, where the handoff owns its
# own Chromium. Once speed-up-login-handoff makes the handoff attach to a
# running browser session, this test starts a session first and then arms.
exec bash "$repo_root/containers/run.sh" full bash -lc "
  set -e
  export LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login
  export LINE_OA_SEND_CHAT_HANDOFF_TTL_SECONDS=$ttl
  bash scripts/start_line_oa_vnc_handoff.sh 2>&1 | tee /tmp/handoff.log &
  handoff=\$!

  url=''
  for _ in \$(seq 1 90); do
    url=\$(grep -Eo 'https://[-a-z0-9]+\.trycloudflare\.com[^ ]*' /tmp/handoff.log | head -1 || true)
    [ -n \"\$url\" ] && break
    sleep 1
  done

  if [ -z \"\$url\" ]; then
    echo 'RESULT: no tunnel URL was emitted'
    tail -5 /tmp/handoff.log
    exit 1
  fi

  # The check the skill currently asks an agent to perform by hand: the URL must
  # be usable from outside, not merely locally.
  code=\$(curl -s -o /tmp/page.html -w '%{http_code}' --max-time 20 \"\$url\" || echo 000)
  if [ \"\$code\" = 200 ] && grep -qi novnc /tmp/page.html; then
    echo \"RESULT: tunnel verified externally (HTTP \$code, noVNC content present)\"
  else
    echo \"RESULT: tunnel URL not externally usable (HTTP \$code)\"
  fi

  echo 'Revoking now rather than waiting for TTL.'
  kill -TERM \$handoff 2>/dev/null || true
  wait \$handoff 2>/dev/null || true
"
