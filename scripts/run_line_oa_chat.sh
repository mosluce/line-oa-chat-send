#!/usr/bin/env bash
# Run the LINE OA CLI with the dedicated runtime that contains Playwright.
# Override LINE_OA_RUNTIME_ROOT, LINE_OA_PYTHON, or PLAYWRIGHT_BROWSERS_PATH
# only when intentionally using a different local runtime.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
runtime_root="${LINE_OA_RUNTIME_ROOT:-/opt/data/.line-oa-automation}"
python_bin="${LINE_OA_PYTHON:-${runtime_root}/venv/bin/python}"
browsers_path="${PLAYWRIGHT_BROWSERS_PATH:-${runtime_root}/ms-playwright}"

if [[ ! -x "$python_bin" ]]; then
  printf 'ERROR: LINE OA runtime Python not found: %s\n' "$python_bin" >&2
  printf 'Set LINE_OA_RUNTIME_ROOT or LINE_OA_PYTHON to an installed local runtime.\n' >&2
  exit 2
fi

if ! "$python_bin" -c 'import playwright' >/dev/null 2>&1; then
  printf 'ERROR: Playwright is unavailable in %s\n' "$python_bin" >&2
  printf 'Install Playwright into that dedicated runtime; do not use the system Python.\n' >&2
  exit 2
fi

if [[ ! -d "$browsers_path" ]]; then
  printf 'ERROR: Playwright browser cache not found: %s\n' "$browsers_path" >&2
  printf 'Set PLAYWRIGHT_BROWSERS_PATH to the matching local browser cache.\n' >&2
  exit 2
fi

export PLAYWRIGHT_BROWSERS_PATH="$browsers_path"
exec "$python_bin" "$script_dir/send_line_oa_chat.py" "$@"
