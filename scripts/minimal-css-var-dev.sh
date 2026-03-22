#!/usr/bin/env bash

cd test/css-var || exit

# Clear Neovim's bytecode cache so local source changes are always picked up
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/nvim/luac"

nvim --clean -u ../minimal-css-var-dev.lua main.css
