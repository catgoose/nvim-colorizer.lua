---@mod colorizer.parser.hwb HWB Parser
---@brief [[
---This module provides a parser for identifying and converting `hwb()` CSS functions to RGB hexadecimal format.
---HWB (Hue, Whiteness, Blackness) is a CSS Color Level 4 color model that is more intuitive than HSL.
---It supports hue in degrees (with angle units), whiteness and blackness as percentages,
---and optional alpha transparency.
---@brief ]]
local M = {}

local color = require("colorizer.color")
local hwb_to_rgb = color.hwb_to_rgb
local utils = require("colorizer.utils")

local hwb_pattern =
  "^hwb%(%s*(-?%d*%.?%d+)([%a]?[%a]?[%a]?[%a]?)%s+(-?%d*%.?%d+)%%?%s+(-?%d*%.?%d+)%%?%s*(/?)%s*(-?%d*%.?%d*)(%%?)%s*%)()"

--- Parses `hwb()` CSS functions and converts them to RGB hexadecimal format.
---@param line string The line of text to parse
---@param i number The starting index within the line where parsing should begin
---@param _ table Parsing options (unused)
---@return number|nil The end index of the parsed `hwb` function within the line, or `nil` if no match was found.
---@return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.parser(line, i, _)
  local min_len = #"hwb(0 0 0)" - 1
  local min, max = math.min, math.max

  if #line < i + min_len then
    return
  end

  local h, h_unit, w, b, sep, a, a_percent, match_end = line:sub(i):match(hwb_pattern)

  if not match_end then
    return
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

  -- Parse whiteness and blackness (percentages, clamped to [0, 1])
  w = tonumber(w)
  b = tonumber(b)
  if not w or not b then
    return
  end
  w = max(0, w / 100)
  b = max(0, b / 100)

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

  local r, g, bl = hwb_to_rgb(h, w, b)
  if not r or not g or not bl then
    return
  end

  if alpha < 1 then
    r, g, bl = color.apply_alpha(r, g, bl, alpha)
  end

  local rgb_hex = utils.rgb_to_hex(r, g, bl)
  return match_end - 1, rgb_hex
end

--- Parser spec for the registry
M.spec = {
  name = "hwb",
  priority = 20,
  dispatch = { kind = "prefix", prefixes = { "hwb" } },
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
