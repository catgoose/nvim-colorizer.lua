---@mod colorizer.parser.oklch OKLCH Parser
---@brief [[
---This module provides a parser for identifying and converting `oklch()` CSS functions to RGB hexadecimal format.
---OKLCH is a perceptual color space that provides better uniformity than HSL.
---It supports lightness as both decimal (0-1) and percentage (0-100%),
---chroma values, hue in degrees, and optional alpha transparency.
---This function is useful for syntax highlighting or color recognition in a text editor.
---@brief ]]
local M = {}

local floor = math.floor
local oklch_to_rgb = require("colorizer.color").oklch_to_rgb
local utils = require("colorizer.utils")

-- oklch has a single hardcoded pattern, cache it at module level
local oklch_pattern =
  "^oklch%(%s*(-?%d*%.?%d+)(%%?)%s+(-?%d*%.?%d+)(%%?)%s+(-?%d*%.?%d+)([%a]?[%a]?[%a]?[%a]?)%s*(/?)%s*(-?%d*%.?%d*)(%%?)%s*%)()"

--- Parses `oklch()` CSS functions and converts them to RGB hexadecimal format.
-- This function matches `oklch()` functions within a line of text, extracting and converting
-- the lightness, chroma, and hue to an RGB color. It handles lightness as decimal or percentage,
-- and an optional alpha (transparency) value.
---@param line string The line of text to parse
---@param i number The starting index within the line where parsing should begin
---@param _ table Parsing options (unused, included for API consistency)
---@return number|nil The end index of the parsed `oklch` function within the line, or `nil` if no match was found.
---@return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.parser(line, i, _)
  local min_len = #"oklch(0 0 0)" - 1
  local min, max = math.min, math.max

  if #line < i + min_len then
    return
  end

  -- Match oklch(L C H) or oklch(L C H / A)
  -- L: 0-1 or 0-100%
  -- C: ≥0, theoretically unbounded (typically ≤0.5), percentage where 100% = 0.4
  -- H: degrees (supports deg, rad, turn, grad units)
  -- A: 0-1 or 0-100% (clamped at parsed-value time)
  --
  -- Pattern notes:
  -- Numbers (L/C/H): -?%d*%.?%d+ (optional minus, optional digits, optional dot, required digits)
  -- Alpha (optional): -?%d*%.?%d* (all parts optional since alpha itself is optional)
  -- Units: [%a]?[%a]?[%a]?[%a]? (0-4 letters for deg/rad/turn/grad, validated later)
  local l, l_percent, c, c_percent, h, h_unit, sep, a, a_percent, match_end = line:sub(i):match(
    oklch_pattern
  )

  if not match_end then
    return
  end

  -- Parse lightness (can be percentage or decimal)
  -- Per W3C spec: clamp to [0%, 100%] or [0.0, 1.0] at parsed-value time
  l = tonumber(l)
  if not l then
    return
  end

  if l_percent == "%" then
    l = l / 100
  end

  -- Clamp to [0, 1] per spec
  l = max(0, min(1, l))

  -- If alpha is present, separator MUST be "/"
  if a and a ~= "" and sep ~= "/" then
    return
  end

  -- Parse chroma
  -- Per W3C spec: minimum 0, maximum "theoretically unbounded" (practice: ≤ 0.5)
  -- Percentage reference: 0% = 0.0, 100% = 0.4 (percentages can exceed 100%)
  -- Negative values clamped to 0 at parsed-value time per spec
  c = tonumber(c)
  if not c then
    return
  end

  if c_percent == "%" then
    c = c * 0.4 / 100 -- 100% = 0.4
  end

  -- Clamp to minimum 0 per spec
  if c < 0 then
    c = 0
  end

  -- Parse hue with angle unit support (deg, rad, turn, grad)
  h = tonumber(h)
  if not h then
    return
  end

  -- Convert angle unit to degrees
  if h_unit == "" or h_unit == "deg" then
    -- Already in degrees
  elseif h_unit == "rad" then
    h = h * (180 / math.pi)
  elseif h_unit == "turn" then
    h = h * 360
  elseif h_unit == "grad" then
    h = h * 0.9 -- 400 grads = 360 degrees, so 1 grad = 0.9 deg
  else
    -- Invalid unit
    return
  end

  -- Normalize hue to 0-360 range
  h = h % 360

  -- Parse alpha if present
  -- Per CSS spec: alpha must be clamped to [0, 1]
  ---@type number
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

    -- Clamp alpha to [0, 1] per CSS spec
    alpha = max(0, min(1, alpha))
  end

  local r, g, b = oklch_to_rgb(l, c, h)
  if not r or not g or not b then
    return
  end

  -- Apply alpha if not fully opaque
  if alpha < 1 then
    r = floor(r * alpha)
    g = floor(g * alpha)
    b = floor(b * alpha)
  end

  local rgb_hex = utils.rgb_to_hex(r, g, b)
  return match_end - 1, rgb_hex
end

return M
