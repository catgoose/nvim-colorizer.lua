---@mod colorizer.parser.lch CIE LCH Parser
---@brief [[
---This module provides a parser for identifying and converting `lch()` CSS functions to RGB hexadecimal format.
---CIE LCH is the cylindrical form of CIE Lab, defined in CSS Color Level 4.
---It supports lightness as a number or percentage, chroma as a number or percentage,
---hue in degrees (with angle units), and optional alpha transparency.
---@brief ]]
local M = {}

local color = require("colorizer.color")
local lch_to_rgb = color.lch_to_rgb
local utils = require("colorizer.utils")

local lch_pattern =
  "^lch%(%s*(-?%d*%.?%d+)(%%?)%s+(-?%d*%.?%d+)(%%?)%s+(-?%d*%.?%d+)([%a]?[%a]?[%a]?[%a]?)%s*(/?)%s*(-?%d*%.?%d*)(%%?)%s*%)()"

--- Parses `lch()` CSS functions and converts them to RGB hexadecimal format.
---@param line string The line of text to parse
---@param i number The starting index within the line where parsing should begin
---@param _ table Parsing options (unused)
---@return number|nil The end index of the parsed `lch` function within the line, or `nil` if no match was found.
---@return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.parser(line, i, _)
  local min_len = #"lch(0 0 0)" - 1
  local min, max = math.min, math.max

  if #line < i + min_len then
    return
  end

  local l, l_percent, c, c_percent, h, h_unit, sep, a, a_percent, match_end =
    line:sub(i):match(lch_pattern)

  if not match_end then
    return
  end

  -- Parse lightness: number (0-100) or percentage (0%-100%)
  l = tonumber(l)
  if not l then
    return
  end
  if l_percent == "%" then
    -- percentage: already in correct range (100% = 100)
  end
  l = max(0, min(100, l))

  -- Parse chroma: number (0-150 typical) or percentage (0%-100% maps to 0-150)
  c = tonumber(c)
  if not c then
    return
  end
  if c_percent == "%" then
    c = c * 1.5 -- 100% = 150
  end
  if c < 0 then
    c = 0
  end

  -- Parse hue with angle unit support
  h = tonumber(h)
  if not h then
    return
  end

  if h_unit == "" or h_unit == "deg" then
    -- Already in degrees
  elseif h_unit == "rad" then
    h = h * (180 / math.pi)
  elseif h_unit == "turn" then
    h = h * 360
  elseif h_unit == "grad" then
    h = h * 0.9
  else
    return
  end

  -- Normalize hue to 0-360 range
  h = h % 360

  -- If alpha is present, separator MUST be "/"
  if a and a ~= "" and sep ~= "/" then
    return
  end

  -- Parse alpha
  local alpha = 1
  if a and a ~= "" then
    local a_num = tonumber(a)
    if not a_num then
      return
    end
    if a_percent == "%" then
      alpha = a_num / 100
    else
      alpha = a_num
    end
    alpha = max(0, min(1, alpha))
  end

  local r, g, b = lch_to_rgb(l, c, h)
  if not r or not g or not b then
    return
  end

  if alpha < 1 then
    r, g, b = color.apply_alpha(r, g, b, alpha)
  end

  local rgb_hex = utils.rgb_to_hex(r, g, b)
  return match_end - 1, rgb_hex
end

--- Parser spec for the registry
M.spec = {
  name = "lch",
  priority = 20,
  dispatch = { kind = "prefix", prefixes = { "lch" } },
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
