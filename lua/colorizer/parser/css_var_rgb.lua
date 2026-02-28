---@mod colorizer.parser.css_var_rgb CSS Variable RGB Parser
---@brief [[
---Parses CSS variables with comma-separated RGB: --name: R,G,B or --name: R, G, B;
---e.g. Catppuccin: --ctp-flamingo: 240,198,198;
---@brief ]]
local M = {}

local utils = require("colorizer.utils")

local pattern = "^--([%w_-]+)%s*:%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*[;%s]*()"

function M.parser(line, i, _)
  if #line < i + 9 then
    return
  end
  local name, r_str, g_str, b_str, match_end = line:sub(i):match(pattern)
  if not match_end then
    return
  end
  local r = tonumber(r_str)
  local g = tonumber(g_str)
  local b = tonumber(b_str)
  if not r or not g or not b then
    return
  end
  r = (r > 255 and 255 or (r < 0 and 0 or r))
  g = (g > 255 and 255 or (g < 0 and 0 or g))
  b = (b > 255 and 255 or (b < 0 and 0 or b))
  local rgb_hex = utils.rgb_to_hex(r, g, b)
  return match_end - 1, rgb_hex
end

M.spec = {
  name = "css_var_rgb",
  priority = 18,
  dispatch = { kind = "prefix", prefixes = { "--" } },
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col, ctx.parser_config)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
