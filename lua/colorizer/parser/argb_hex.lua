--- This module provides a parser for extracting `0xAARRGGBB` hexadecimal color values and converting them to RGB hex.
-- This format is commonly used in Android apps for color values, where the color includes an alpha (transparency) component.
-- The function parses the color, applies the alpha value to each RGB channel, and returns the resulting RGB hex string.
-- @module colorizer.parser.rgb_hex
local M = {}

local bit = require("bit")
local utils = require("colorizer.utils")
local floor, min = math.floor, math.min
local band, rshift, lshift = bit.band, bit.rshift, bit.lshift

local argb_minimum_length = #"0xAARRGGBB" - 1

--- Parses a `0xAARRGGBB` formatted hexadecimal color and converts it to an RGB hex value.
-- This function reads a color from a line of text, expecting it in the `0xAARRGGBB` format (common in Android apps).
-- It extracts the alpha (AA), red (RR), green (GG), and blue (BB) components, applies the alpha to the RGB channels, and outputs
-- the resulting RGB color in hexadecimal format.
-- @param line string The line of text to parse
-- @param i number The starting index within the line where parsing should begin
-- @return number|nil The end index of the parsed hex value within the line, or `nil` if parsing failed
-- @return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.argb_hex_parser(line, i)
  if #line < i + argb_minimum_length then
    return
  end

  local j = i + 2
  local n = j + 8
  local alpha
  local v = 0

  while j <= min(n, #line) do
    local b = line:byte(j)
    if not utils.byte_is_hex(b) then
      break
    end
    if j - i <= 3 then
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

  if length == 10 then -- 0xAARRGGBB
    alpha = band(rshift(v, 24), 0xFF) / 255
    r = floor(band(rshift(v, 16), 0xFF) * alpha)
    g = floor(band(rshift(v, 8), 0xFF) * alpha)
    b = floor(band(v, 0xFF) * alpha)
  elseif length == 8 then -- 0xRRGGBB
    r = band(rshift(v, 16), 0xFF)
    g = band(rshift(v, 8), 0xFF)
    b = band(v, 0xFF)
  elseif length == 5 then -- 0xRGB
    r = band(rshift(v, 8), 0xF) * 17
    g = band(rshift(v, 4), 0xF) * 17
    b = band(v, 0xF) * 17
  else
    return
  end

  alpha = tonumber(alpha) / 255
  local r = floor(band(rshift(v, 16), 0xFF) * alpha)
  local g = floor(band(rshift(v, 8), 0xFF) * alpha)
  local b = floor(band(v, 0xFF) * alpha)
  local rgb_hex = string.format("%02x%02x%02x", r, g, b)
  return length, rgb_hex
end

return M.argb_hex_parser
