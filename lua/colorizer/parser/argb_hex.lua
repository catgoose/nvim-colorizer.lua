--- This module provides a parser for extracting `0xAARRGGBB` hexadecimal color values and converting them to RGB hex.
-- This format is commonly used in Android apps for color values, where the color includes an alpha (transparency) component.
-- The function parses the color, applies the alpha value to each RGB channel, and returns the resulting RGB hex string.
-- @module colorizer.parser.rgb_hex
local M = {}

local bit = require("bit")
local floor, min = math.floor, math.min
local band, rshift, lshift = bit.band, bit.rshift, bit.lshift

local utils = require("colorizer.utils")

--- Parses a `0xAARRGGBB` formatted hexadecimal color and converts it to an RGB hex value.
-- This function reads a color from a line of text, expecting it in the `0xAARRGGBB` format (common in Android apps).
-- It extracts the alpha (AA), red (RR), green (GG), and blue (BB) components, applies the alpha to the RGB channels, and outputs
-- the resulting RGB color in hexadecimal format.
-- @param line string The line of text to parse
-- @param i number The starting index within the line where parsing should begin
-- @return number|nil The end index of the parsed hex value within the line, or `nil` if parsing failed
-- @return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.argb_hex_parser(line, i)
  -- Minimum length of a valid hex color (e.g., "0xRGB")
  local minlen = #"0xRGB" - 1
  -- Maximum length of a valid hex color (e.g., "0xAARRGGBB")
  local maxlen = #"0xAARRGGBB" - 1

  -- Ensure the line has enough characters to contain a valid hex color
  if #line < i + minlen then
    return
  end

  local j = i + 2 -- Skip the "0x" prefix
  local n = j + maxlen
  local alpha, r, g, b
  local v = 0 -- Holds the parsed value

  -- Parse the hex characters starting from the given index
  while j <= min(n, #line) do
    local byte = line:byte(j)
    -- Stop parsing if the character is not a valid hex digit
    if not utils.byte_is_hex(byte) then
      break
    end
    -- Shift the current value left by 4 bits and add the parsed hex digit
    v = utils.parse_hex(byte) + lshift(v, 4)
    j = j + 1
  end

  -- If the next character is alphanumeric, the value is invalid
  if #line >= j and utils.byte_is_alphanumeric(line:byte(j)) then
    return
  end

  local length = j - i -- Calculate the length of the parsed hex value

  -- Parse the color components based on the detected length
  if length == 10 then -- 0xAARRGGBB
    alpha = band(rshift(v, 24), 0xFF) / 255 -- Extract and normalize the alpha value
    r = floor(band(rshift(v, 16), 0xFF) * alpha) -- Apply alpha to red
    g = floor(band(rshift(v, 8), 0xFF) * alpha) -- Apply alpha to green
    b = floor(band(v, 0xFF) * alpha) -- Apply alpha to blue
  elseif length == 8 then -- 0xRRGGBB
    r = band(rshift(v, 16), 0xFF) -- Extract red
    g = band(rshift(v, 8), 0xFF) -- Extract green
    b = band(v, 0xFF) -- Extract blue
  elseif length == 5 then -- 0xRGB
    r = band(rshift(v, 8), 0xF) * 17 -- Scale single hex digit to full byte
    g = band(rshift(v, 4), 0xF) * 17 -- Scale single hex digit to full byte
    b = band(v, 0xF) * 17 -- Scale single hex digit to full byte
  else
    return
  end

  local rgb_hex = string.format("%02x%02x%02x", r, g, b)
  return length, rgb_hex
end

return M.argb_hex_parser
