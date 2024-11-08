---Helper function to parse argb
local M = {}

local bit = require("bit")
local utils = require("colorizer.utils")
local floor, min = math.floor, math.min
local band, rshift, lshift = bit.band, bit.rshift, bit.lshift

local ARGB_MINIMUM_LENGTH = #"0xAARRGGBB" - 1
---parse for 0xaarrggbb and return rgb hex.
-- a format used in android apps
---@param line string: line to parse
---@param i number: index of line from where to start parsing
---@return number|nil: index of line where the hex value ended
---@return string|nil: rgb hex value
function M.argb_hex_parser(line, i)
  if #line < i + ARGB_MINIMUM_LENGTH then
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
  if length ~= 10 then
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
