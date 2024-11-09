local bit = require "bit"
local floor, min = math.floor, math.min
local band, rshift, lshift = bit.band, bit.rshift, bit.lshift

local utils = require "colorizer.utils"
local byte_is_alphanumeric = utils.byte_is_alphanumeric
local byte_is_hex = utils.byte_is_hex
local parse_hex = utils.parse_hex

local parser = {}

---parse for #rrggbbaa and return rgb hex.
---@param line string: line to parse
---@param i number: index of line from where to start parsing
---@param opts table: Containing minlen, maxlen, valid_lengths
---@return number|nil: index of line where the hex value ended
---@return string|nil: rgb hex value
function parser.rgba_hex_parser(line, i, opts)
  local minlen, maxlen, valid_lengths = opts.minlen, opts.maxlen, opts.valid_lengths
  local j = i + 1
  if #line < j + minlen - 1 then
    return
  end

  if i > 1 and byte_is_alphanumeric(line:byte(i - 1)) then
    return
  end

  local n = j + maxlen
  local alpha
  local v = 0

  while j <= min(n, #line) do
    local b = line:byte(j)
    if not byte_is_hex(b) then
      break
    end
    if j - i >= 7 then
      alpha = parse_hex(b) + lshift(alpha or 0, 4)
    else
      v = parse_hex(b) + lshift(v, 4)
    end
    j = j + 1
  end

  if #line >= j and byte_is_alphanumeric(line:byte(j)) then
    return
  end

  local length = j - i
  if length ~= 4 and length ~= 7 and length ~= 9 then
    return
  end

  if alpha then
    alpha = tonumber(alpha) / 255
    local r = floor(band(rshift(v, 16), 0xFF) * alpha)
    local g = floor(band(rshift(v, 8), 0xFF) * alpha)
    local b = floor(band(v, 0xFF) * alpha)
    local rgb_hex = string.format("%02x%02x%02x", r, g, b)
    return 9, rgb_hex
  end
  return (valid_lengths[length - 1] and length), line:sub(i + 1, i + length - 1)
end

return parser.rgba_hex_parser
