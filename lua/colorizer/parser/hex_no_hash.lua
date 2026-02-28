---@mod colorizer.parser.hex_no_hash Hex Without Hash Parser
---@brief [[
---Parses 6-digit (RRGGBB) or 8-digit (RRGGBBAA) hex color values without a leading '#'.
---Only matches at word boundaries to avoid false positives.
---@brief ]]
local M = {}

local bit = require("bit")
local band, rshift, lshift = bit.band, bit.rshift, bit.lshift

local color = require("colorizer.color")
local utils = require("colorizer.utils")

local HEX_BYTES = {}
do
  for b = 0x30, 0x39 do
    HEX_BYTES[#HEX_BYTES + 1] = b
  end
  for b = 0x41, 0x46 do
    HEX_BYTES[#HEX_BYTES + 1] = b
  end
  for b = 0x61, 0x66 do
    HEX_BYTES[#HEX_BYTES + 1] = b
  end
end

---@param line string
---@param i number 1-based column
---@param opts table { rrggbb: boolean, rrggbbaa: boolean }
---@return number|nil, string|nil
function M.parser(line, i, opts)
  if i > 1 and utils.byte_is_alphanumeric(line:byte(i - 1)) then
    return
  end

  local line_len = #line
  if line_len < i + 5 then
    return
  end

  local v, alpha = 0, 0
  local j = i
  while j <= math.min(i + 7, line_len) do
    local b = line:byte(j)
    if not utils.byte_is_hex(b) then
      break
    end
    if j - i >= 6 then
      alpha = utils.parse_hex(b) + lshift(alpha, 4)
    else
      v = utils.parse_hex(b) + lshift(v, 4)
    end
    j = j + 1
  end

  local len = j - i
  if len ~= 6 and len ~= 8 then
    return
  end
  if len == 6 and not opts.rrggbb then
    return
  end
  if len == 8 and not opts.rrggbbaa then
    return
  end
  if j <= line_len and utils.byte_is_alphanumeric(line:byte(j)) then
    return
  end

  if len == 6 then
    local r = band(rshift(v, 16), 0xFF)
    local g = band(rshift(v, 8), 0xFF)
    local b = band(v, 0xFF)
    return len, utils.rgb_to_hex(r, g, b)
  end

  alpha = alpha / 255
  local r, g, b = color.apply_alpha(
    band(rshift(v, 16), 0xFF),
    band(rshift(v, 8), 0xFF),
    band(v, 0xFF),
    alpha
  )
  return len, utils.rgb_to_hex(r, g, b)
end

M.spec = {
  name = "hex_no_hash",
  priority = 12,
  dispatch = { kind = "byte", bytes = HEX_BYTES },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col, ctx.parser_config)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
