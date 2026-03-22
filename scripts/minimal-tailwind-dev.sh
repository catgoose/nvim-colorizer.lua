#!/usr/bin/env bash

cd test/tailwind || exit

if [ ! -d node_modules ]; then
  echo "Installing Tailwind CSS dependencies..."
  npm install
fi

# Clear Neovim's bytecode cache so local source changes are always picked up
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/nvim/luac"

nvim --clean -u ../minimal-tailwind-dev.lua tailwind.html
