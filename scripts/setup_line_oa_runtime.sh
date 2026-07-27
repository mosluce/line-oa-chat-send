#!/usr/bin/env bash
# Provision a private, caller-chosen Python runtime for the LINE OA CLI.
# This never creates a browser profile or requests LINE credentials.
set -euo pipefail

runtime_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime-dir)
      [[ $# -ge 2 ]] || { printf 'ERROR: --runtime-dir requires a value\n' >&2; exit 2; }
      runtime_dir="$2"
      shift 2
      ;;
    --help|-h)
      printf 'Usage: %s --runtime-dir <private-runtime-directory>\n' "${0##*/}"
      exit 0
      ;;
    *)
      printf 'ERROR: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$runtime_dir" ]]; then
  printf 'ERROR: choose a private runtime location with --runtime-dir; no default directory is assumed.\n' >&2
  exit 2
fi
if ! command -v uv >/dev/null 2>&1; then
  printf 'ERROR: uv is required for safe isolated setup. Install uv, then retry.\n' >&2
  exit 2
fi

mkdir -p "$runtime_dir"
chmod 700 "$runtime_dir"
uv venv "$runtime_dir/venv"
uv pip install --python "$runtime_dir/venv/bin/python" playwright
chmod 700 "$runtime_dir/venv"
printf 'SETUP OK\n'
printf 'Next: export LINE_OA_PYTHON=%q\n' "$runtime_dir/venv/bin/python"
printf 'Then: bash scripts/run_line_oa_chat.sh --recipient "Recipient name" --message "Message text"\n'
