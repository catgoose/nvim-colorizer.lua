#!/usr/bin/env bash
# Generate HTML documentation using LDoc
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check for ldoc
if ! command -v ldoc &>/dev/null; then
  echo "ldoc not found. Install via:"
  echo "  luarocks install ldoc"
  exit 1
fi

# LuaCATS annotations (@class, @field, @alias) conflict with LDoc builtins.
# Work in a temp copy so we can strip them without touching the real source.
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

cp -r "$ROOT_DIR/lua" "$WORK_DIR/lua"
cp "$ROOT_DIR/config.ld" "$WORK_DIR/config.ld"
# Preprocess README: convert GFM pipe tables to HTML, strip TOC block
if [ -f "$ROOT_DIR/README.md" ]; then
  python3 "$SCRIPT_DIR/md_table_to_html.py" < "$ROOT_DIR/README.md" > "$WORK_DIR/README.md"
fi

# Strip LuaCATS-only annotations that clash with LDoc
find "$WORK_DIR/lua" -name '*.lua' -exec sed -i \
  -e 's/^---@class/-- @class/' \
  -e 's/^---@field/-- @field/' \
  -e 's/^---@alias/-- @alias/' \
  {} +

echo "Generating HTML docs with ldoc..."
cd "$WORK_DIR"
ldoc .

# Copy generated HTML back
mkdir -p "$ROOT_DIR/doc/html"
cp -r "$WORK_DIR/doc/html/"* "$ROOT_DIR/doc/html/"

echo "Generated HTML docs in doc/html/"
