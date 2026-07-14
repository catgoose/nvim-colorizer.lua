---@mod colorizer.parser.ls_colors LS_COLORS Parser
---@brief [[
---Parses LS_COLORS / SGR color-producing snippets such as:
---  - `=NN` plain 8-color (30-37 fg, 40-47 bg)
---  - `=NN` bright 8-color (90-97 fg, 100-107 bg)
---  - `=01;NN` bold-promoted fg becomes the bright variant
---  - `=38;5;NNN` / `=48;5;NNN` 256-color
---  - `=38;2;R;G;B` / `=48;2;R;G;B` truecolor
---
---Walks semicolon-separated codes starting after `=` until a non-digit /
---non-semicolon byte (typically `:` or whitespace). Foreground wins when both
---are present. 256-color values reuse the xterm palette so users do not need
---to duplicate it in custom parsers.
---@brief ]]
local M = {}

local xterm = require("colorizer.parser.xterm")

local function is_digit(byte)
  return byte and byte >= 0x30 and byte <= 0x39
end

-- Collect the contiguous [digit;]+ value run starting at `i+1`.
-- Returns (tokens, end_pos) where end_pos is 1 past the last consumed byte.
-- tokens is the array of numeric strings split on ';'.
local function collect_value(line, i)
  local n = #line
  local j = i + 1
  while j <= n do
    local b = line:byte(j)
    if b == 0x3B or is_digit(b) then -- ';' or digit
      j = j + 1
    else
      break
    end
  end
  if j == i + 1 then
    return nil
  end
  local tokens = {}
  for tok in line:sub(i + 1, j - 1):gmatch("([^;]+)") do
    tokens[#tokens + 1] = tok
  end
  return tokens, j
end

-- Walk tokens; track first fg/bg color and any bold (brightness) flag.
-- Color slots hold either a 0-255 palette index (number) or
-- { r = .., g = .., b = .. } for truecolor.
local function resolve_color(tokens)
  local fg, bg, brightness
  local k, len = 1, #tokens
  while k <= len do
    local num = tonumber(tokens[k])
    if num then
      if num == 1 then
        brightness = 1
      elseif num >= 30 and num <= 37 and not fg then
        fg = num - 30
      elseif num >= 40 and num <= 47 and not bg then
        bg = num - 40
      elseif num >= 90 and num <= 97 and not fg then
        fg = num - 90 + 8
      elseif num >= 100 and num <= 107 and not bg then
        bg = num - 100 + 8
      elseif num == 38 or num == 48 then
        local is_bg = (num == 48)
        local sub = tonumber(tokens[k + 1] or "")
        if sub == 5 then
          local idx = tonumber(tokens[k + 2] or "")
          if idx and idx >= 0 and idx <= 255 then
            if is_bg and not bg then
              bg = idx
            elseif not is_bg and not fg then
              fg = idx
            end
            k = k + 2
          end
        elseif sub == 2 then
          local r = tonumber(tokens[k + 2] or "")
          local g = tonumber(tokens[k + 3] or "")
          local b = tonumber(tokens[k + 4] or "")
          if r and g and b and r <= 255 and g <= 255 and b <= 255 then
            local rgb = { r = r, g = g, b = b }
            if is_bg and not bg then
              bg = rgb
            elseif not is_bg and not fg then
              fg = rgb
            end
            k = k + 4
          end
        end
      end
    end
    k = k + 1
  end
  return fg or bg, brightness
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
  local tokens, end_pos = collect_value(line, i)
  if not tokens then
    return nil
  end
  local color, brightness = resolve_color(tokens)
  if color == nil then
    return nil
  end
  -- `end_pos` is 1 past the last consumed byte, so the consumed run from
  -- position `i` (the `=`) inclusive is `end_pos - i` bytes long.
  local consumed = end_pos - i
  if type(color) == "table" then
    return consumed, string.format("%02x%02x%02x", color.r, color.g, color.b)
  end
  -- Bold promotes the 8 plain colors (0-7) to their bright variants (8-15).
  if color < 8 and brightness == 1 then
    color = color + 8
  end
  local hex = xterm.lookup_256(color)
  if hex then
    return consumed, hex
  end
end

M.spec = {
  name = "ls_colors",
  priority = 10,
  -- `byte+fallback` (not `byte`) so '=' is not exclusive: when no color
  -- resolves, subsequent prefix/fallback parsers (including user custom
  -- parsers with prefixes = { "=" }) still get a chance.
  dispatch = { kind = "byte+fallback", bytes = { 0x3D } }, -- '='
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
