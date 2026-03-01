#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--check" ]]; then
  stylua --check lua/
else
  stylua lua/
fi
