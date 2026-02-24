#!/usr/bin/env bash

set -euo pipefail

# Generate vimdoc using lemmy-help
# Install: cargo install lemmy-help --features=cli
#      or: download from https://github.com/numToStr/lemmy-help/releases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT="$PROJECT_DIR/doc/colorizer.txt"

# Check for lemmy-help
if command -v lemmy-help &>/dev/null; then
  LEMMY=lemmy-help
elif [ -x "$PROJECT_DIR/deps/lemmy-help" ]; then
  LEMMY="$PROJECT_DIR/deps/lemmy-help"
else
  echo "lemmy-help not found. Install via:"
  echo "  cargo install lemmy-help --features=cli"
  echo "  or download from https://github.com/numToStr/lemmy-help/releases"
  exit 1
fi

mkdir -p "$PROJECT_DIR/doc"

# List source files in logical order: main module first, then config,
# then remaining modules, then parsers
echo "Generating vimdoc with $LEMMY..."

$LEMMY -f \
  "$PROJECT_DIR/lua/colorizer.lua" \
  "$PROJECT_DIR/lua/colorizer/config.lua" \
  "$PROJECT_DIR/lua/colorizer/buffer.lua" \
  "$PROJECT_DIR/lua/colorizer/color.lua" \
  "$PROJECT_DIR/lua/colorizer/constants.lua" \
  "$PROJECT_DIR/lua/colorizer/matcher.lua" \
  "$PROJECT_DIR/lua/colorizer/utils.lua" \
  "$PROJECT_DIR/lua/colorizer/usercmds.lua" \
  "$PROJECT_DIR/lua/colorizer/trie.lua" \
  "$PROJECT_DIR/lua/colorizer/sass.lua" \
  "$PROJECT_DIR/lua/colorizer/tailwind.lua" \
  "$PROJECT_DIR/lua/colorizer/parser/argb_hex.lua" \
  "$PROJECT_DIR/lua/colorizer/parser/hsl.lua" \
  "$PROJECT_DIR/lua/colorizer/parser/names.lua" \
  "$PROJECT_DIR/lua/colorizer/parser/oklch.lua" \
  "$PROJECT_DIR/lua/colorizer/parser/rgb.lua" \
  "$PROJECT_DIR/lua/colorizer/parser/rgba_hex.lua" \
  "$PROJECT_DIR/lua/colorizer/parser/xterm.lua" \
  >"$OUTPUT"

echo "$OUTPUT created"
