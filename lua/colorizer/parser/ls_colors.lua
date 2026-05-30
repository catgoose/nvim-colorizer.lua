---@mod colorizer.parser.ls_colors LS_COLORS Parser
---@brief [[
---Parses LS_COLORS / SGR color-producing snippets such as:
---  - `=38;5;NNN` and `=48;5;NNN` (256-color foreground/background)
---  - `=38;2;R;G;B` and `=48;2;R;G;B` (24-bit truecolor)
---
---Leading semicolon-separated style codes (e.g. `01;`) are skipped before the
---color directive. 256-color values reuse the xterm palette so users do not
---need to duplicate it in custom parsers.
---@brief ]]
local M = {}

local xterm = require("colorizer.parser.xterm")

-- Patterns:
--   ^=([%d;]*)(38|48);2;(%d+);(%d+);(%d+)()  -- truecolor
--   ^=([%d;]*)(38|48);5;(%d+)()              -- 256-color
-- Lua patterns lack alternation, so we try each selector explicitly.
local truecolor_pats = {
  "^=([%d;]*)38;2;(%d+);(%d+);(%d+)()",
  "^=([%d;]*)48;2;(%d+);(%d+);(%d+)()",
}
local indexed_pats = {
  "^=([%d;]*)38;5;(%d+)()",
  "^=([%d;]*)48;5;(%d+)()",
}

local function is_digit(byte)
  return byte and byte >= 0x30 and byte <= 0x39
end

---Parse an LS_COLORS/SGR color snippet starting at `i` in `line`.
---@param line string
---@param i number 1-indexed start position; must point at `=`
---@return number|nil length consumed from `i`
---@return string|nil rgb_hex
function M.parser(line, i)
  if line:byte(i) ~= 0x3D then -- '='
    return nil
  end
  local s = line:sub(i)

  for _, pat in ipairs(truecolor_pats) do
    local _prefix, r, g, b, end_pos = s:match(pat)
    if r then
      r, g, b = tonumber(r), tonumber(g), tonumber(b)
      if r and g and b and r <= 255 and g <= 255 and b <= 255 then
        if not is_digit(s:byte(end_pos)) then
          return end_pos - 1, string.format("%02x%02x%02x", r, g, b)
        end
      end
    end
  end

  for _, pat in ipairs(indexed_pats) do
    local _prefix, n, end_pos = s:match(pat)
    if n then
      local idx = tonumber(n)
      if idx and not is_digit(s:byte(end_pos)) then
        local hex = xterm.lookup_256(idx)
        if hex then
          return end_pos - 1, hex
        end
      end
    end
  end
end

M.spec = {
  name = "ls_colors",
  priority = 10,
  dispatch = { kind = "byte", bytes = { 0x3D } }, -- '='
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
