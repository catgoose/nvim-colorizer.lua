---@mod colorizer.parser.rgba_hex RGBA Hex Parser
---@brief [[
---This module provides a parser for identifying and converting `#RRGGBBAA` hexadecimal color values to RGB hexadecimal format.
---It is commonly used in Android apps for colors with an alpha (transparency) component.
---The function reads the color, applies the alpha to each RGB channel, and returns the resulting RGB hex string.
---@brief ]]
local M = {}

local bit = require("bit")
local band, rshift, lshift = bit.band, bit.rshift, bit.lshift

local color = require("colorizer.color")
local utils = require("colorizer.utils")

--- Parses `#RRGGBBAA` hexadecimal colors and converts them to RGB hex format.
-- This function matches `#RRGGBBAA` format colors within a line, handling alpha transparency if specified.
-- It checks the length of the color string to match expected valid lengths (e.g., 4, 7, 9 characters).
---@param line string The line of text to parse for the hex color
---@param i number The starting index within the line where parsing should begin
---@param opts table Options containing:
--- - `minlen` (number): Minimum length of the color string
--- - `maxlen` (number): Maximum length of the color string
--- - `valid_lengths` (table): Set of valid lengths (e.g., `{3, 4, 6, 8}`)
---@return number|nil The end index of the parsed hex color within the line, or `nil` if parsing failed
---@return string|nil The RGB hexadecimal color (e.g., "ff0000" for red), or `nil` if parsing failed
function M.parser(line, i, opts)
  local minlen, maxlen, valid_lengths = opts.minlen, opts.maxlen, opts.valid_lengths
  local line_length = #line

  if line_length < i + minlen - 1 then
    return
  end

  -- Ensure the preceding character is not alphanumeric
  if i > 1 and utils.byte_is_alphanumeric(line:byte(i - 1)) then
    return
  end

  local j = i + 1
  local v, alpha = 0, 0

  -- Parse valid hex characters
  while j <= math.min(i + maxlen, line_length) do
    local b = line:byte(j)
    if not utils.byte_is_hex(b) then
      break
    end
    if j - i >= 7 then
      -- Parsing alpha component for #RRGGBBAA
      alpha = utils.parse_hex(b) + lshift(alpha, 4)
    else
      -- Parsing RGB components
      v = utils.parse_hex(b) + lshift(v, 4)
    end
    j = j + 1
  end

  -- Ensure the succeeding character is not alphanumeric
  if j <= line_length and utils.byte_is_alphanumeric(line:byte(j)) then
    return
  end

  local parsed_length = j - i
  if not valid_lengths[parsed_length - 1] then
    return
  end

  if parsed_length == 4 then
    -- Handle #RGB
    local r = utils.parse_hex(line:byte(i + 1)) * 17
    local g = utils.parse_hex(line:byte(i + 2)) * 17
    local b = utils.parse_hex(line:byte(i + 3)) * 17
    return 4, utils.rgb_to_hex(r, g, b)
  elseif parsed_length == 5 then
    -- Handle #RGBA
    local r = utils.parse_hex(line:byte(i + 1)) * 17
    local g = utils.parse_hex(line:byte(i + 2)) * 17
    local b = utils.parse_hex(line:byte(i + 3)) * 17
    alpha = utils.parse_hex(line:byte(i + 4)) / 15
    return 5, utils.rgb_to_hex(color.apply_alpha(r, g, b, alpha))
  elseif parsed_length == 9 then
    if opts and opts.hash_aarrggbb then
      local full = 0
      for k = 1, 8 do
        full = utils.parse_hex(line:byte(i + k)) + lshift(full, 4)
      end
      alpha = band(rshift(full, 24), 0xFF) / 255
      local r, g, b = color.apply_alpha(
        band(rshift(full, 16), 0xFF),
        band(rshift(full, 8), 0xFF),
        band(full, 0xFF),
        alpha
      )
      return 9, utils.rgb_to_hex(r, g, b)
    end
    alpha = alpha / 255
    local r, g, b = color.apply_alpha(band(rshift(v, 16), 0xFF), band(rshift(v, 8), 0xFF), band(v, 0xFF), alpha)
    return 9, utils.rgb_to_hex(r, g, b)
  end

  -- Fallback: #RRGGBB or other lengths
  return parsed_length, line:sub(i + 1, i + parsed_length - 1)
end

--- Parser spec for the registry
M.spec = {
  name = "rgba_hex",
  priority = 10,
  dispatch = { kind = "byte", bytes = { 0x23 } },
  -- No config_defaults: controlled by hex.* in config
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col, ctx.parser_config)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
