---@mod colorizer.parser.lab CIE Lab Parser
---@brief [[
---This module provides a parser for identifying and converting `lab()` CSS functions to RGB hexadecimal format.
---CIE Lab is a perceptually uniform color space defined in CSS Color Level 4.
---It supports lightness as a number or percentage, a/b axes as numbers or percentages,
---and optional alpha transparency.
---@brief ]]
local M = {}

local color = require("colorizer.color")
local lab_to_rgb = color.lab_to_rgb
local utils = require("colorizer.utils")

local lab_pattern =
  "^lab%(%s*(-?%d*%.?%d+)(%%?)%s+(-?%d*%.?%d+)(%%?)%s+(-?%d*%.?%d+)(%%?)%s*(/?)%s*(-?%d*%.?%d*)(%%?)%s*%)()"

--- Parses `lab()` CSS functions and converts them to RGB hexadecimal format.
---@param line string The line of text to parse
---@param i number The starting index within the line where parsing should begin
---@param _ table Parsing options (unused)
---@return number|nil The end index of the parsed `lab` function within the line, or `nil` if no match was found.
---@return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.parser(line, i, _)
  local min_len = #"lab(0 0 0)" - 1
  local min, max = math.min, math.max

  if #line < i + min_len then
    return
  end

  local l, l_percent, a_val, a_percent, b_val, b_percent, sep, alpha, alpha_percent, match_end =
    line:sub(i):match(lab_pattern)

  if not match_end then
    return
  end

  -- Parse lightness: number (0-100) or percentage (0%-100%)
  l = tonumber(l)
  if not l then
    return
  end
  if l_percent == "%" then
    -- percentage: 100% = 100
    -- already in correct range
  end
  l = max(0, min(100, l))

  -- Parse a axis: number (-125 to 125) or percentage (-100% to 100% maps to -125 to 125)
  a_val = tonumber(a_val)
  if not a_val then
    return
  end
  if a_percent == "%" then
    a_val = a_val * 1.25 -- 100% = 125
  end

  -- Parse b axis: number (-125 to 125) or percentage (-100% to 100% maps to -125 to 125)
  b_val = tonumber(b_val)
  if not b_val then
    return
  end
  if b_percent == "%" then
    b_val = b_val * 1.25 -- 100% = 125
  end

  -- If alpha is present, separator MUST be "/"
  if alpha and alpha ~= "" and sep ~= "/" then
    return
  end

  -- Parse alpha
  local a = 1
  if alpha and alpha ~= "" then
    local a_num = tonumber(alpha)
    if not a_num then
      return
    end
    if alpha_percent == "%" then
      a = a_num / 100
    else
      a = a_num
    end
    a = max(0, min(1, a))
  end

  local r, g, b = lab_to_rgb(l, a_val, b_val)
  if not r or not g or not b then
    return
  end

  if a < 1 then
    r, g, b = color.apply_alpha(r, g, b, a)
  end

  local rgb_hex = utils.rgb_to_hex(r, g, b)
  return match_end - 1, rgb_hex
end

--- Parser spec for the registry
M.spec = {
  name = "lab",
  priority = 20,
  dispatch = { kind = "prefix", prefixes = { "lab" } },
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
