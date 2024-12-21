--- Manages matching and parsing of color patterns in buffers.
-- This module provides functions for setting up and applying color parsers
-- for different color formats such as RGB, HSL, hexadecimal, and named colors.
-- It uses a trie-based structure to optimize prefix-based parsing.
-- @module colorizer.matcher

local M = {}

local Trie = require("colorizer.trie")
local min, max = math.min, math.max

local parsers = {
  argb_hex = require("colorizer.parser.argb_hex").parser,
  color_name = require("colorizer.parser.names").parser,
  hsl_function = require("colorizer.parser.hsl").parser,
  rgb_function = require("colorizer.parser.rgb").parser,
  rgba_hex = require("colorizer.parser.rgba_hex").parser,
  sass_name = require("colorizer.sass").parser,
}

parsers.prefix = {
  ["_0x"] = parsers.argb_hex,
  ["_rgb"] = parsers.rgb_function,
  ["_rgba"] = parsers.rgb_function,
  ["_hsl"] = parsers.hsl_function,
  ["_hsla"] = parsers.hsl_function,
}

---Form a trie stuct with the given prefixes
---@param matchers table: List of prefixes, {"rgb", "hsl"}
---@param matchers_trie table: Table containing information regarding non-trie based parsers
---@return function: function which will just parse the line for enabled parsers
local function compile(matchers, matchers_trie)
  local trie = Trie(matchers_trie)

  local function parse_fn(line, i, bufnr)
    -- prefix #
    if matchers.rgba_hex_parser then
      if line:byte(i) == ("#"):byte() then
        return parsers.rgba_hex(line, i, matchers.rgba_hex_parser)
      end
    end

    -- prefix $, SASS Color names
    if matchers.sass_name_parser then
      if line:byte(i) == ("$"):byte() then
        return parsers.sass_name(line, i, bufnr)
      end
    end

    -- Prefix 0x, rgba, rgb, hsla, hsl
    local prefix = trie:longest_prefix(line, i)
    if prefix then
      local fn = "_" .. prefix
      if parsers.prefix[fn] then
        return parsers.prefix[fn](line, i, matchers[prefix])
      end
    end

    -- Color names
    if matchers.color_name_parser then
      return parsers.color_name(line, i, matchers.color_name_parser)
    end
  end

  return parse_fn
end

local matcher_cache = {}
---Parse the given options and return a function with enabled parsers.
--if no parsers enabled then return false
--Do not try make the function again if it is present in the cache
---@param options table: options created in `colorizer.setup`
---@return function|boolean: function which will just parse the line for enabled parsers
function M.make(options)
  if not options then
    return false
  end

  local enable_names = options.names
  local enable_names_custom = options.names_custom
  local enable_sass = options.sass and options.sass.enable
  local enable_tailwind = options.tailwind
  local enable_RGB = options.RGB
  local enable_RRGGBB = options.RRGGBB
  local enable_RRGGBBAA = options.RRGGBBAA
  local enable_AARRGGBB = options.AARRGGBB
  local enable_rgb = options.rgb_fn
  local enable_hsl = options.hsl_fn

  -- Rather than use bit.lshift or calculate 2^x, use precalculated values to
  -- create unique bitmask
  local matcher_key = 0
    + (enable_names and 1 or 0)
    + (enable_names_custom and 2 or 0)
    + (enable_RGB and 4 or 0)
    + (enable_RRGGBB and 8 or 0)
    + (enable_RRGGBBAA and 16 or 0)
    + (enable_AARRGGBB and 32 or 0)
    + (enable_rgb and 64 or 0)
    + (enable_hsl and 128 or 0)
    + ((enable_tailwind == true or enable_tailwind == "normal") and 256 or 0)
    + (enable_tailwind == "lsp" and 512 or 0)
    + (enable_tailwind == "both" and 1024 or 0)
    + (enable_sass and 2048 or 0)

  if matcher_key == 0 then
    return false
  end

  local loop_parse_fn = matcher_cache[matcher_key]
  if loop_parse_fn then
    return loop_parse_fn
  end

  local matchers = {}
  local matchers_prefix = {}

  if enable_names then
    matchers.color_name_parser = matchers.color_name_parser or {}
    matchers.color_name_parser.color_names = enable_names
  end
  if enable_names_custom then
    matchers.color_name_parser = matchers.color_name_parser or {}
    matchers.color_name_parser.names_custom = enable_names_custom
  end
  if enable_tailwind then
    matchers.color_name_parser = matchers.color_name_parser or {}
    matchers.color_name_parser.tailwind = enable_tailwind
  end
  if enable_sass then
    matchers.sass_name_parser = true
  end

  local valid_lengths = { [3] = enable_RGB, [6] = enable_RRGGBB, [8] = enable_RRGGBBAA }
  local minlen, maxlen
  for k, v in pairs(valid_lengths) do
    if v then
      minlen = minlen and min(k, minlen) or k
      maxlen = maxlen and max(k, maxlen) or k
    end
  end

  if minlen then
    matchers.rgba_hex_parser = {}
    matchers.rgba_hex_parser.valid_lengths = valid_lengths
    matchers.rgba_hex_parser.maxlen = maxlen
    matchers.rgba_hex_parser.minlen = minlen
  end

  --  TODO: 2024-11-05 - Add custom prefixes
  if enable_AARRGGBB then
    table.insert(matchers_prefix, "0x")
  end

  if enable_rgb and enable_hsl then
    table.insert(matchers_prefix, "hsla")
    table.insert(matchers_prefix, "rgba")
    table.insert(matchers_prefix, "rgb")
    table.insert(matchers_prefix, "hsl")
  elseif enable_rgb then
    table.insert(matchers_prefix, "rgba")
    table.insert(matchers_prefix, "rgb")
  elseif enable_hsl then
    table.insert(matchers_prefix, "hsla")
    table.insert(matchers_prefix, "hsl")
  end

  for _, value in ipairs(matchers_prefix) do
    matchers[value] = { prefix = value }
  end

  loop_parse_fn = compile(matchers, matchers_prefix)
  matcher_cache[matcher_key] = loop_parse_fn

  return loop_parse_fn
end

---Reset the cache of matchers
---Called from colorizer.setup
function M.reset_cache()
  matcher_cache = {}
end

return M
