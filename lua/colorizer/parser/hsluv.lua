---@mod colorizer.parser.hsluv HSLuv Parser
---@brief [[
---Parses `hsluv()` and `hsluvu()` (with alpha) and converts to RGB hex.
---H 0-360, S and L 0-100; alpha optional.
---@brief ]]
local M = {}

local floor = math.floor
local color = require("colorizer.color")
local hsluv_mod = require("colorizer.hsluv")
local utils = require("colorizer.utils")

local pattern_cache = {}

local function make_pattern(prefix)
  return "^"
    .. prefix
    .. "%(%s*([.%d]+)([deg]*)([turn]*)(%s?)%s*(,?)%s*([.%d]+)%%?(%s?)%s*(,?)%s*([.%d]+)%%?%s*(/?,?)%s*([.%d]*)([%%]?)%s*%)()"
end

function M.parser(line, i, opts)
  local prefix = opts.prefix
  local min_len = (prefix == "hsluvu" and #"hsluvu(0,0,0,0)" or #"hsluv(0,0,0)") - 1
  local pattern = pattern_cache[prefix]
  if not pattern then
    pattern = make_pattern(prefix)
    pattern_cache[prefix] = pattern
  end

  if #line < i + min_len then
    return
  end

  local h, deg, turn, ssep1, csep1, s, ssep2, csep2, l, sep3, a, percent_sign, match_end =
    line:sub(i):match(pattern)
  if not match_end then
    return
  end

  local min_commas = 2
  if a and a ~= "" then
    min_commas = 3
  end

  if not ((deg == "") or (deg == "deg") or (turn == "turn")) then
    return
  end

  local c_seps = ("%s%s%s"):format(csep1, csep2, sep3)
  local s_seps = ("%s%s"):format(ssep1, ssep2)
  if not utils.validate_css_seps(c_seps, s_seps, a ~= nil and a ~= "", min_commas, 2) then
    return
  end

  if not a or a == "" then
    a = 1
  else
    a = tonumber(a)
    if percent_sign == "%" then
      a = a / 100
    end
    a = a > 1 and 1 or a
  end

  h = tonumber(h) or 0
  if turn == "turn" then
    h = 360 * h
  end
  if h > 360 then
    h = 360 * ((h / 360) - floor(h / 360))
  end

  s = tonumber(s)
  s = s and (s > 100 and 100 or s) or 0
  l = tonumber(l)
  l = l and (l > 100 and 100 or l) or 0

  local rgb = hsluv_mod.hsluv_to_rgb({ h, s, l })
  if not rgb then
    return
  end

  local r = math.floor(rgb[1] * 255 + 0.5)
  local g = math.floor(rgb[2] * 255 + 0.5)
  local b = math.floor(rgb[3] * 255 + 0.5)
  r = (r < 0 and 0 or (r > 255 and 255 or r))
  g = (g < 0 and 0 or (g > 255 and 255 or g))
  b = (b < 0 and 0 or (b > 255 and 255 or b))
  if a < 1 then
    r, g, b = color.apply_alpha(r, g, b, a)
  end
  local rgb_hex = utils.rgb_to_hex(r, g, b)
  return match_end - 1, rgb_hex
end

M.spec = {
  name = "hsluv",
  priority = 20,
  dispatch = { kind = "prefix", prefixes = { "hsluv", "hsluvu" } },
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col, { prefix = ctx.prefix })
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
