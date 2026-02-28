---@mod colorizer.parser.xcolor Xcolor (LaTeX) Parser
---@brief [[
---Parses LaTeX xcolor syntax: colorname!number (e.g. red!30 = 30% red, 70% white).
---Uses the same named colors as the names parser.
---@brief ]]
local M = {}

local names = require("colorizer.parser.names")
local utils = require("colorizer.utils")

local pattern = "^([%a]+)!(%d+)()"

local function build_names_matcher_opts(opts)
  local p = opts and opts.parsers
  if not p then
    return nil
  end
  return {
    color_names = true,
    color_names_opts = p.names or { lowercase = true, camelcase = true, uppercase = false, strip_digits = false },
    names_custom = p.names and p.names.custom_hashed,
    tailwind_names = p.tailwind and p.tailwind.enable,
  }
end

function M.parser(line, i, opts)
  if #line < i + 3 then
    return
  end
  local word, num_str, match_end = line:sub(i):match(pattern)
  if not word or not num_str or not match_end then
    return
  end
  local m_opts = build_names_matcher_opts(opts)
  if not m_opts then
    return
  end
  local hex = names.lookup_name(word, m_opts)
  if not hex then
    return
  end
  local pct = tonumber(num_str)
  if not pct or pct > 100 then
    return
  end
  local j = i + match_end - 1
  if j <= #line and utils.byte_is_alphanumeric(line:byte(j)) then
    return
  end
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  if not r or not g or not b then
    return
  end
  local t = pct / 100
  r = math.floor(r * t + 255 * (1 - t) + 0.5)
  g = math.floor(g * t + 255 * (1 - t) + 0.5)
  b = math.floor(b * t + 255 * (1 - t) + 0.5)
  r = (r > 255 and 255 or (r < 0 and 0 or r))
  g = (g > 255 and 255 or (g < 0 and 0 or g))
  b = (b > 255 and 255 or (b < 0 and 0 or b))
  local rgb_hex = utils.rgb_to_hex(r, g, b)
  return match_end - 1, rgb_hex
end

M.spec = {
  name = "xcolor",
  priority = 26,
  dispatch = { kind = "fallback" },
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col, ctx.opts)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
