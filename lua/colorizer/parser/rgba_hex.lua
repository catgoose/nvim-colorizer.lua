--- This module provides a parser for identifying and converting `#RRGGBBAA` hexadecimal color values to RGB hexadecimal format.
-- It is commonly used in Android apps for colors with an alpha (transparency) component.
-- The function reads the color, applies the alpha to each RGB channel, and returns the resulting RGB hex string.
-- @module colorizer.parser.rgba_hex

local M = {}

local bit = require("bit")
local floor, min = math.floor, math.min
local lshift = bit.lshift

local utils = require("colorizer.utils")

local parse_opts = {
  [4] = { multiplier = 17, alpha_divisor = 1 }, -- #RGB
  [5] = { multiplier = 17, alpha_divisor = 15 }, -- #RGBA
  [9] = { multiplier = 1, alpha_divisor = 255 }, -- #RRGGBBAA
}
local function parse_color(line, i, length)
  local opts = parse_opts[length]
  if not opts then
    return
  end
  local r = utils.parse_hex(line:byte(i + 1)) * opts.multiplier
  local g = utils.parse_hex(line:byte(i + 2)) * opts.multiplier
  local b = utils.parse_hex(line:byte(i + 3)) * opts.multiplier
  if length > 4 then
    -- Handle transparency (RGBA or RRGGBBAA)
    local alpha = utils.parse_hex(line:byte(i + 4)) / opts.alpha_divisor
    r, g, b = floor(r * alpha), floor(g * alpha), floor(b * alpha)
  end
  local rgb_hex = utils.rgb_to_hex(r, g, b)
  return length, rgb_hex
end

--- Parses `#RRGGBBAA` hexadecimal colors and converts them to RGB hex format.
-- This function matches `#RRGGBBAA` format colors within a line, handling alpha transparency if specified.
-- It checks the length of the color string to match expected valid lengths (e.g., 4, 7, 9 characters).
-- @param line string The line of text to parse for the hex color
-- @param i number The starting index within the line where parsing should begin
-- @param opts table Options containing:
--   - `minlen` (number): Minimum length of the color string
--   - `maxlen` (number): Maximum length of the color string
--   - `valid_lengths` (table): Set of valid lengths (e.g., `{3, 4, 6, 8}`)
-- @return number|nil The end index of the parsed hex color within the line, or `nil` if parsing failed
-- @return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.parser(line, i, opts)
  local minlen, maxlen, valid_lengths = opts.minlen, opts.maxlen, opts.valid_lengths
  local j = i + 1
  if #line < j + minlen - 1 then
    return
  end

  if i > 1 and utils.byte_is_alphanumeric(line:byte(i - 1)) then
    return
  end

  local n = j + maxlen
  local alpha
  local v = 0

  while j <= min(n, #line) do
    local b = line:byte(j)
    if not utils.byte_is_hex(b) then
      break
    end
    if j - i >= 7 then
      alpha = utils.parse_hex(b) + lshift(alpha or 0, 4)
    else
      v = utils.parse_hex(b) + lshift(v, 4)
    end
    j = j + 1
  end

  if #line >= j and utils.byte_is_alphanumeric(line:byte(j)) then
    return
  end

  local length = j - i
  if not valid_lengths[length - 1] then
    return
  end

  if parse_opts[length] then
    return parse_color(line, i, length)
  end

  return (valid_lengths[length - 1] and length), line:sub(i + 1, i + length - 1)
end

return M
