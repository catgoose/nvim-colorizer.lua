#!/usr/bin/env bash

cd test/tailwind || exit

if [ ! -d node_modules ]; then
  echo "Installing Tailwind CSS dependencies..."
  npm install
fi

nvim --clean -u ../minimal-tailwind.lua tailwind.html
