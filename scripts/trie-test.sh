#!/usr/bin/env bash

cd test/trie || exit
nvim --clean --headless -u test.lua -c quit
file=trie-test.txt

if [[ -f $file ]]; then
  # Display small list file
  echo -e "\nTrie tests:\n"
  cat "$file"
fi
