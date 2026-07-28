#!/usr/bin/env bash
# Default test path. Runs from the host and drives the container variants.
#
# Nothing here creates an externally reachable URL. Every handoff case exercised
# below is refused before the script reaches the point of starting a tunnel, so
# this path needs no external egress beyond pulling the LINE login page.
#
# Tunnel behaviour is covered separately and opt-in: containers/test/tunnel.sh
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
run="$repo_root/containers/run.sh"
image="${LINE_OA_TEST_IMAGE:-line-oa-test}"

pass=0
fail=0
check() {
  local name="$1"; shift
  if "$@" >/tmp/line-oa-check.out 2>&1; then
    printf '  ok    %s\n' "$name"; pass=$((pass + 1))
  else
    printf '  FAIL  %s\n' "$name"; sed 's/^/          /' /tmp/line-oa-check.out | head -6; fail=$((fail + 1))
  fi
}

# Asserts a command fails with a specific exit code and message fragment.
refuses() {
  local name="$1" want_code="$2" want_text="$3"; shift 3
  local out code
  out="$("$@" 2>&1)" && code=0 || code=$?
  if [[ "$code" == "$want_code" ]] && grep -qF "$want_text" <<<"$out"; then
    printf '  ok    %s\n' "$name"; pass=$((pass + 1))
  else
    printf '  FAIL  %s (exit=%s, wanted %s containing %q)\n' "$name" "$code" "$want_code" "$want_text"
    sed 's/^/          /' <<<"$out" | head -4; fail=$((fail + 1))
  fi
}

printf '\n== architecture guard ==\n'
refuses 'unset host arch is refused' 2 'emulation cannot be ruled out' \
  docker run --rm "${image}:full" true
refuses 'architecture mismatch is refused' 2 'architecture mismatch' \
  docker run --rm -e LINE_OA_CONTAINER_HOST_ARCH=amd64 "${image}:full" true
check 'matching architecture runs' bash "$run" full true

printf '\n== full variant is complete ==\n'
check 'handoff dependencies present' bash "$run" full bash -lc '
  for c in Xvfb x11vnc websockify caddy cloudflared chromium python3; do command -v "$c" >/dev/null || { echo "missing: $c"; exit 1; }; done
  for d in /usr/share/novnc /usr/share/noVNC; do [ -d "$d" ] && exit 0; done; echo "missing noVNC assets"; exit 1'
check 'playwright importable' bash "$run" full \
  /opt/line-oa-runtime/venv/bin/python -c 'import playwright'
# PYTHONPYCACHEPREFIX keeps bytecode out of the read-only source mount.
check 'send CLI compiles' bash "$run" full bash -lc \
  'PYTHONPYCACHEPREFIX=/tmp/pycache /opt/line-oa-runtime/venv/bin/python -m py_compile scripts/send_line_oa_chat.py'
check 'send CLI --help' bash "$run" full \
  bash -lc 'LINE_OA_PYTHON=/opt/line-oa-runtime/venv/bin/python bash scripts/run_line_oa_chat.sh --help'

printf '\n== isolation ==\n'
check 'workspace is read-only' bash "$run" full \
  bash -lc 'touch /workspace/__rw_probe 2>/dev/null && { echo "workspace was writable"; exit 1; }; exit 0'
check 'profile is on container-native storage' bash "$run" full \
  bash -lc 'mount | grep -q " /opt/data/chromium .*ext4" || { mount | grep " /opt/data/chromium "; exit 1; }'
refuses 'host profile override is refused' 2 'never uses a host profile' \
  env LINE_OA_SEND_CHAT_CHROMIUM_PROFILE=/tmp/pretend-real-profile bash "$run" full true

printf '\n== browser session ==\n'
check 'session starts, CDP responds, LINE login page loads' bash "$run" full bash -lc '
  bash scripts/start_line_oa_chromium.sh >/tmp/c.log 2>&1 &
  for _ in $(seq 1 60); do curl --max-time 2 -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1 && break; sleep 1; done
  curl --max-time 3 -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1 || { tail -5 /tmp/c.log; exit 1; }
  curl -fsS http://127.0.0.1:9222/json/list | grep -q "line.biz" || { echo "no LINE page"; exit 1; }'
check 'second session is refused' bash "$run" full bash -lc '
  bash scripts/start_line_oa_chromium.sh >/tmp/c.log 2>&1 &
  for _ in $(seq 1 60); do curl --max-time 2 -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1 && break; sleep 1; done
  bash scripts/start_line_oa_chromium.sh >/dev/null 2>&1 && { echo "second start was allowed"; exit 1; }
  exit 0'
# Two paths, and which one fires depends on whether DISPLAY is already set. The
# CDP "already running" guard sits behind display setup, so without DISPLAY the
# operator is told Xvfb failed rather than that a session is already running.
# Recorded as a finding for speed-up-login-handoff.
check 'without DISPLAY the refusal names Xvfb, not the live session' bash "$run" full bash -lc '
  bash scripts/start_line_oa_chromium.sh >/tmp/c.log 2>&1 &
  for _ in $(seq 1 60); do curl --max-time 2 -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1 && break; sleep 1; done
  out="$(bash scripts/start_line_oa_chromium.sh 2>&1)" || true
  grep -qF "could not start private Xvfb display" <<<"$out"'
check 'with DISPLAY set the refusal names the live CDP endpoint' bash "$run" full bash -lc '
  bash scripts/start_line_oa_chromium.sh >/tmp/c.log 2>&1 &
  for _ in $(seq 1 60); do curl --max-time 2 -fsS http://127.0.0.1:9222/json/version >/dev/null 2>&1 && break; sleep 1; done
  out="$(DISPLAY=:99 bash scripts/start_line_oa_chromium.sh 2>&1)" || true
  grep -qF "already reachable" <<<"$out"'

printf '\n== handoff refusals (all pre-tunnel) ==\n'
refuses 'missing handoff purpose' 2 'LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login' \
  bash "$run" full bash scripts/start_line_oa_vnc_handoff.sh
refuses 'wrong handoff purpose' 2 'LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login' \
  bash "$run" full bash -lc 'LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=browse bash scripts/start_line_oa_vnc_handoff.sh'
refuses 'TTL below range' 2 'must be an integer from 60 to 3600' \
  bash "$run" full bash -lc 'LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login LINE_OA_SEND_CHAT_HANDOFF_TTL_SECONDS=59 bash scripts/start_line_oa_vnc_handoff.sh'
refuses 'TTL above range' 2 'must be an integer from 60 to 3600' \
  bash "$run" full bash -lc 'LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login LINE_OA_SEND_CHAT_HANDOFF_TTL_SECONDS=3601 bash scripts/start_line_oa_vnc_handoff.sh'
refuses 'non-numeric TTL' 2 'must be an integer from 60 to 3600' \
  bash "$run" full bash -lc 'LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login LINE_OA_SEND_CHAT_HANDOFF_TTL_SECONDS=abc bash scripts/start_line_oa_vnc_handoff.sh'

printf '\n== dependency detection drives real verdicts ==\n'
refuses 'no-handoff-deps names the missing commands' 2 'missing protected-handoff dependencies' \
  bash "$run" no-handoff-deps bash -lc 'LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login bash scripts/start_line_oa_vnc_handoff.sh'
refuses 'no-runtime reports no Playwright runtime' 2 'No Python runtime with Playwright' \
  bash "$run" no-runtime bash scripts/run_line_oa_chat.sh --recipient x --message y
# The disclaimer text mentions sudo, so the assertion is that no line *invokes*
# sudo, not that the word is absent.
check 'no-handoff-deps prints operator install instructions, invoking no sudo' bash -c '
  out="$(bash '"$run"' no-handoff-deps bash -lc "LINE_OA_SEND_CHAT_HANDOFF_PURPOSE=line-login bash scripts/start_line_oa_vnc_handoff.sh" 2>&1 || true)"
  grep -q "apt-get install" <<<"$out" || { echo "no install instructions"; exit 1; }
  grep -qE "^[[:space:]]*sudo " <<<"$out" && { echo "instructions invoke sudo"; exit 1; }
  exit 0'
check 'unauth-profile has an initialized but session-free profile' bash "$run" unauth-profile \
  bash -lc '[ -e /opt/data/chromium/Default ] || { echo "profile not initialized"; exit 1; }'

printf '\n== summary ==\n'
printf '  %d passed, %d failed\n\n' "$pass" "$fail"
(( fail == 0 ))
