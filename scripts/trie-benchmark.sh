#!/usr/bin/env bash

cd test/trie || exit
nvim --clean --headless -u benchmark.lua -c quit
file=trie-benchmark.txt
if [[ -f $file ]]; then
  # Format and display the output
  echo -e "\nTrie benchmarks:\n"
  column -L -t -s $'\t' <"$file"
fi
