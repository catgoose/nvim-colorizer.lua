#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP="lua package.path = './?/init.lua;./?.lua;' .. package.path"

if [[ $# -gt 0 ]]; then
  nvim --headless --noplugin -u NONE -c "$BOOTSTRAP" \
    -c "lua require('tests.helpers')" \
    -c "lua MiniTest.run_file('$1')"
else
  nvim --headless --noplugin -u NONE -c "$BOOTSTRAP" \
    -c "lua require('tests.helpers')" \
    -c "lua MiniTest.run()"
fi
