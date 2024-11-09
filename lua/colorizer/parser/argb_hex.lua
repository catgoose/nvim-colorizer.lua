local bit = require "bit"
local floor, min = math.floor, math.min
local band, rshift, lshift = bit.band, bit.rshift, bit.lshift

local utils = require "colorizer.utils"
local byte_is_alphanumeric = utils.byte_is_alphanumeric
local byte_is_hex = utils.byte_is_hex
local parse_hex = utils.parse_hex

local parser = {}

---parse for 0xAARRGGBB, 0xRRGGBB, or 0xRGB and return rgb hex.
---@param line string: line to parse
---@param i number: index of line from where to start parsing
---@return number|nil: index of line where the hex value ended
---@return string|nil: rgb hex value
function parser.argb_hex_parser(line, i)
  local minlen = #"0xRGB" - 1
  local maxlen = #"0xAARRGGBB" - 1
  if #line < i + minlen then
    return
  end

  local j = i + 2
  local n = j + maxlen
  local alpha, r, g, b
  local v = 0

  while j <= min(n, #line) do
    local byte = line:byte(j) -- Renamed to `byte` to avoid conflict with `b`
    if not byte_is_hex(byte) then
      break
    end
    v = parse_hex(byte) + lshift(v, 4)
    j = j + 1
  end

  if #line >= j and byte_is_alphanumeric(line:byte(j)) then
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

  local rgb_hex = string.format("%02x%02x%02x", r, g, b)
  return length, rgb_hex
end

return parser.argb_hex_parser
