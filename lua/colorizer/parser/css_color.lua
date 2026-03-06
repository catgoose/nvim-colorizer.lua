---@mod colorizer.parser.css_color CSS color() Parser
---@brief [[
---This module provides a parser for identifying and converting CSS `color()` functions to RGB hexadecimal format.
---The CSS `color()` function allows specifying colors in arbitrary color spaces.
---Supported color spaces: srgb, srgb-linear, display-p3, a98-rgb, prophoto-rgb, rec2020.
---Values can be numbers (0-1) or percentages. Optional alpha transparency is supported.
---@brief ]]
local M = {}

local color = require("colorizer.color")
local css_color_to_rgb = color.css_color_to_rgb
local utils = require("colorizer.utils")

local valid_spaces = {
  ["srgb"] = true,
  ["srgb-linear"] = true,
  ["display-p3"] = true,
  ["a98-rgb"] = true,
  ["prophoto-rgb"] = true,
  ["rec2020"] = true,
}

local color_pattern =
  "^color%(%s*([%w%-]+)%s+(-?%d*%.?%d+)(%%?)%s+(-?%d*%.?%d+)(%%?)%s+(-?%d*%.?%d+)(%%?)%s*(/?)%s*(-?%d*%.?%d*)(%%?)%s*%)()"

--- Parses `color()` CSS functions and converts them to RGB hexadecimal format.
---@param line string The line of text to parse
---@param i number The starting index within the line where parsing should begin
---@param _ table Parsing options (unused)
---@return number|nil The end index of the parsed `color` function within the line, or `nil` if no match was found.
---@return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.parser(line, i, _)
  local min_len = #"color(srgb 0 0 0)" - 1
  local min, max = math.min, math.max

  if #line < i + min_len then
    return
  end

  local space, r, r_pct, g, g_pct, b, b_pct, sep, a, a_pct, match_end =
    line:sub(i):match(color_pattern)

  if not match_end then
    return
  end

  -- Validate color space
  if not valid_spaces[space] then
    return
  end

  -- Parse channel values (0-1 or percentage where 100% = 1)
  r = tonumber(r)
  g = tonumber(g)
  b = tonumber(b)
  if not r or not g or not b then
    return
  end

  if r_pct == "%" then
    r = r / 100
  end
  if g_pct == "%" then
    g = g / 100
  end
  if b_pct == "%" then
    b = b / 100
  end

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
    if a_pct == "%" then
      alpha = a_num / 100
    else
      alpha = a_num
    end
    alpha = max(0, min(1, alpha))
  end

  local out_r, out_g, out_b = css_color_to_rgb(space, r, g, b)
  if not out_r or not out_g or not out_b then
    return
  end

  if alpha < 1 then
    out_r, out_g, out_b = color.apply_alpha(out_r, out_g, out_b, alpha)
  end

  local rgb_hex = utils.rgb_to_hex(out_r, out_g, out_b)
  return match_end - 1, rgb_hex
end

--- Parser spec for the registry
M.spec = {
  name = "css_color",
  priority = 20,
  dispatch = { kind = "prefix", prefixes = { "color" } },
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
