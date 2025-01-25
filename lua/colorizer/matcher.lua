--[[-- Manages matching and parsing of color patterns in buffers.
This module provides functions for setting up and applying color parsers
for different color formats such as RGB, HSL, hexadecimal, and named colors.
It uses a trie-based structure to optimize prefix-based parsing.
]]
-- @module colorizer.matcher
local M = {}

local Trie = require("colorizer.trie")
local min, max = math.min, math.max

local parsers = {
  color_name = require("colorizer.parser.names").parser,
  argb_hex = require("colorizer.parser.argb_hex").parser,
  hsl_function = require("colorizer.parser.hsl").parser,
  rgb_function = require("colorizer.parser.rgb").parser,
  rgba_hex = require("colorizer.parser.rgba_hex").parser,
  --  TODO: 2024-12-21 - Should this be moved into parsers module?
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
---@param hooks? table: Table of hook functions
-- hooks.disable_line_highlight: function to be called after parsing the line
---@return function: function which will just parse the line for enabled parsers
local function compile(matchers, matchers_trie, hooks)
  local trie = Trie(matchers_trie)

  local function parse_fn(line, i, bufnr, line_nr)
    if
      hooks
      and hooks.disable_line_highlight
      and hooks.disable_line_highlight(line, line_nr, bufnr)
    then
      return
    end

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

    if matchers.color_name_parser then
      return parsers.color_name(line, i, matchers.color_name_parser)
    end
  end

  return parse_fn
end

local matcher_cache
---Reset matcher cache
-- Called from colorizer.setup
function M.reset_cache()
  matcher_cache = {}
end
do
  M.reset_cache()
end

---Parse the given options and return a function with enabled parsers.
--if no parsers enabled then return false
--Do not try make the function again if it is present in the cache
---@param ud_opts table: options created in `colorizer.setup`
---@return function|boolean: function which will just parse the line for enabled parsers
function M.make(ud_opts)
  if not ud_opts then
    return false
  end

  local enable_names = ud_opts.names
  local enable_names_lowercase = ud_opts.names_opts and ud_opts.names_opts.lowercase
  local enable_names_camelcase = ud_opts.names_opts and ud_opts.names_opts.camelcase
  local enable_names_uppercase = ud_opts.names_opts and ud_opts.names_opts.uppercase
  local enable_names_strip_digits = ud_opts.names_opts and ud_opts.names_opts.strip_digits
  local enable_names_custom = ud_opts.names_custom_hashed
  local enable_sass = ud_opts.sass and ud_opts.sass.enable
  local enable_tailwind = ud_opts.tailwind
  local enable_RGB = ud_opts.RGB
  local enable_RGBA = ud_opts.RGBA
  local enable_RRGGBB = ud_opts.RRGGBB
  local enable_RRGGBBAA = ud_opts.RRGGBBAA
  local enable_AARRGGBB = ud_opts.AARRGGBB
  local enable_rgb = ud_opts.rgb_fn
  local enable_hsl = ud_opts.hsl_fn

  -- Rather than use bit.lshift or calculate 2^x, use precalculated values to
  -- create unique bitmask
  local matcher_mask = 0
    + (enable_names and 1 or 0)
    + (enable_names_lowercase and 2 or 0)
    + (enable_names_camelcase and 4 or 0)
    + (enable_names_uppercase and 8 or 0)
    + (enable_names_strip_digits and 16 or 0)
    + (enable_names_custom and 32 or 0)
    + (enable_RGB and 64 or 0)
    + (enable_RGBA and 128 or 0)
    + (enable_RRGGBB and 256 or 0)
    + (enable_RRGGBBAA and 512 or 0)
    + (enable_AARRGGBB and 1024 or 0)
    + (enable_rgb and 2048 or 0)
    + (enable_hsl and 4096 or 0)
    + (enable_tailwind == "normal" and 8192 or 0)
    + (enable_tailwind == "lsp" and 16384 or 0)
    + (enable_tailwind == "both" and 32768 or 0)
    + (enable_sass and 65536 or 0)

  if matcher_mask == 0 then
    return false
  end

  local matcher_key = enable_names_custom
      and string.format("%d|%s", matcher_mask, enable_names_custom.hash)
    or matcher_mask

  local loop_parse_fn = matcher_cache[matcher_key]
  if loop_parse_fn then
    return loop_parse_fn
  end

  local matchers = {}
  local matchers_prefix = {}

  local enable_tailwind_names = enable_tailwind == "normal" or enable_tailwind == "both"
  if enable_names or enable_names_custom or enable_tailwind_names then
    matchers.color_name_parser = matchers.color_name_parser or {}
    if enable_names then
      matchers.color_name_parser.color_names = enable_names
      matchers.color_name_parser.color_names_opts = {
        lowercase = enable_names_lowercase,
        camelcase = enable_names_camelcase,
        uppercase = enable_names_uppercase,
        strip_digits = enable_names_strip_digits,
      }
    end
    if enable_names_custom then
      matchers.color_name_parser.names_custom = enable_names_custom
    end
    if enable_tailwind_names then
      matchers.color_name_parser.tailwind_names = enable_tailwind_names
    end
  end

  matchers.sass_name_parser = enable_sass or nil

  local valid_lengths =
    { [3] = enable_RGB, [4] = enable_RGBA, [6] = enable_RRGGBB, [8] = enable_RRGGBBAA }
  local minlen, maxlen
  for k, v in pairs(valid_lengths) do
    if v then
      minlen = minlen and min(k, minlen) or k
      maxlen = maxlen and max(k, maxlen) or k
    end
  end
  if minlen then
    matchers.rgba_hex_parser = {
      valid_lengths = valid_lengths,
      minlen = minlen,
      maxlen = maxlen,
    }
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

  loop_parse_fn = compile(matchers, matchers_prefix, ud_opts.hooks)
  matcher_cache[matcher_mask] = loop_parse_fn

  return loop_parse_fn
end

return M
