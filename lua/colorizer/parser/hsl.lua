---@mod colorizer.parser.hsl HSL Parser
---@brief [[
---This module provides a parser for identifying and converting `hsl()` and `hsla()` CSS functions to RGB hexadecimal format.
---It supports various CSS color value formats, including degrees (`deg`), turns (`turn`), percentages, and alpha transparency.
---This function is useful for syntax highlighting or color recognition in a text editor.
---@brief ]]
local M = {}

local floor = math.floor
local hsl_to_rgb = require("colorizer.color").hsl_to_rgb
local utils = require("colorizer.utils")

local pattern_cache = {}

--- Parses `hsl()` and `hsla()` CSS functions and converts them to RGB hexadecimal format.
-- This function matches `hsl()` or `hsla()` functions within a line of text, extracting and converting the hue, saturation, and luminance
-- to an RGB color. It handles angles in degrees and turns, percentages, and an optional alpha (transparency) value.
---@param line string The line of text to parse
---@param i number The starting index within the line where parsing should begin
---@param opts table Parsing options, including:
---  - `prefix` (string): "hsl" or "hsla" to specify the CSS function type.
---@return number|nil The end index of the parsed `hsl/hsla` function within the line, or `nil` if no match was found.
---@return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.parser(line, i, opts)
  local min_len = #"hsla(0,0,0)" - 1
  local min_commas, min_spaces = 2, 2
  local pattern = pattern_cache[opts.prefix]
  if not pattern then
    pattern = "^"
      .. opts.prefix
      .. "%(%s*([.%d]+)([deg]*)([turn]*)(%s?)%s*(,?)%s*([.%d]+)%%?(%s?)%s*(,?)%s*([.%d]+)%%?%s*(/?,?)%s*([.%d]*)([%%]?)%s*%)()"
    pattern_cache[opts.prefix] = pattern
  end

  if opts.prefix == "hsl" then
    min_len = #"hsl(0,0,0)" - 1
  end

  if #line < i + min_len then
    return
  end

  local h, deg, turn, ssep1, csep1, s, ssep2, csep2, l, sep3, a, percent_sign, match_end =
    line:sub(i):match(pattern)
  if not match_end then
    return
  end
  if a == "" then
    a = nil
  else
    min_commas = min_commas + 1
  end

  -- Ensure the hue is either in degrees, turns, or unspecified (defaulting to degrees)
  if not ((deg == "") or (deg == "deg") or (turn == "turn")) then
    return
  end

  local c_seps = ("%s%s%s"):format(csep1, csep2, sep3)
  local s_seps = ("%s%s"):format(ssep1, ssep2)
  if not utils.validate_css_seps(c_seps, s_seps, a ~= nil, min_commas, min_spaces) then
    return
  end

  if not a then
    a = 1
  else
    a = tonumber(a)
    -- Convert percentage alpha to decimal if applicable
    if percent_sign == "%" then
      a = a / 100
    end
    if a > 1 then
      a = 1
    end
  end

  h = tonumber(h) or 1
  -- Convert turns to degrees if applicable
  if turn == "turn" then
    h = 360 * h
  end

  -- Normalize hue within 360 degrees if it exceeds this value
  if h > 360 then
    local turns = h / 360
    h = 360 * (turns - floor(turns))
  end

  -- Clamp saturation and luminance to a maximum of 100%
  s = tonumber(s)
  if s > 100 then
    s = 100
  end
  l = tonumber(l)
  if l > 100 then
    l = 100
  end

  local r, g, b = hsl_to_rgb(h / 360, s / 100, l / 100)
  if not r or not g or not b then
    return
  end

  local rgb_hex = utils.rgb_to_hex(r, g, b)
  return match_end - 1, rgb_hex
end

--- Parser spec for the registry
M.spec = {
  name = "hsl",
  priority = 20,
  dispatch = { kind = "prefix", prefixes = { "hsl", "hsla" } },
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col, { prefix = ctx.prefix })
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
