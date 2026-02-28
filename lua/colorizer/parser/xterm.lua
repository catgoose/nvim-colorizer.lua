---@mod colorizer.parser.xterm Xterm Parser
---@brief [[
---This module provides a parser for identifying and converting xterm color codes to RGB hexadecimal format.
---It supports both #xNN format (decimal, 0-255) and ANSI escape sequences \e[38;5;NNNm for xterm 256-color palette.
---The function reads the color code and returns the corresponding RGB hex string from the xterm color palette.
---@brief ]]
local M = {}

-- Xterm 256-color palette (0-255) as RGB hex strings
local xterm_palette = {
  "000000", "800000", "008000", "808000", "000080", "800080", "008080", "c0c0c0",
  "808080", "ff0000", "00ff00", "ffff00", "0000ff", "ff00ff", "00ffff", "ffffff",
  -- 16-231: 6x6x6 color cube
}
-- Fill in the 6x6x6 color cube
for r = 0, 5 do
  for g = 0, 5 do
    for b = 0, 5 do
      local idx = 16 + 36 * r + 6 * g + b
      local function scale(x) return x == 0 and 0 or 95 + 40 * (x - 1) end
      xterm_palette[idx + 1] = string.format("%02x%02x%02x", scale(r), scale(g), scale(b))
    end
  end
end
-- 232-255: grayscale ramp
for i = 0, 23 do
  local level = 8 + i * 10
  xterm_palette[233 + i] = string.format("%02x%02x%02x", level, level, level)
end

-- Pre-built pattern tables (constant, no need to recreate per call)
local ansi_256_patterns = {
  "^\\e%[38;5;(%d?%d?%d)m",   -- literal '\e'
  "^\27%[38;5;(%d?%d?%d)m",    -- ASCII 27
  "^\x1b%[38;5;(%d?%d?%d)m",   -- hex escape
}
local ansi_16_patterns = {
  "^\\e%[(%d+);(%d+)m",   -- literal '\e'
  "^\27%[(%d+);(%d+)m",    -- ASCII 27
  "^\x1b%[(%d+);(%d+)m",   -- hex escape
}

local const = require("colorizer.constants")

--- Parses xterm color codes and converts them to RGB hex format.
-- This function matches following color codes:
--   1. #xNN format (decimal, 0-255).
--   2. ANSI escape sequences \e[38;5;NNNm for xterm 256-color palette.
--   3. ANSI escape sequences \e[X;Ym for xterm 16-color palette.
-- It returns the corresponding RGB hex string from the xterm color palette.
---@param line string The line of text to parse for xterm color codes
---@param i number The starting index within the line where parsing should begin
---@return number|nil The end index of the parsed xterm color code within the line, or `nil` if parsing failed
---@return string|nil The RGB hexadecimal color from the xterm palette, or `nil` if parsing failed
function M.parser(line, i)
  -- #xNN (decimal, 0-255)
  if line:byte(i) == const.bytes.hash and line:byte(i + 1) == const.bytes.x then
    local num = line:sub(i + 2):match("^(%d?%d?%d)")
    if num then
      local idx = tonumber(num) or -1
      if idx >= 0 and idx <= 255 then
        local next_byte = line:byte(i + 2 + #num)
        if not next_byte or not (
          (next_byte >= 0x30 and next_byte <= 0x39) or  -- 0-9
          (next_byte >= 0x41 and next_byte <= 0x5A) or  -- A-Z
          (next_byte >= 0x61 and next_byte <= 0x7A) or  -- a-z
          next_byte == 0x5F                              -- _
        ) then
          return 2 + #num, xterm_palette[idx + 1]
        end
      end
    end
  end
  -- \e[38;5;NNNm (decimal, 0-255), support both literal '\e' and actual escape char
  for _, esc_pat in ipairs(ansi_256_patterns) do
    local esc_match = line:sub(i):match(esc_pat)
    if esc_match then
      local idx = tonumber(esc_match) or -1
      if idx >= 0 and idx <= 255 then
        -- Use string.find to get the end index of the match
        local _, end_idx = line:sub(i):find(esc_pat)
        if end_idx then
          return end_idx, xterm_palette[idx + 1]
        else
          return 7 + #esc_match, xterm_palette[idx + 1]
        end
      end
    end
  end
  -- \e[X;Ym for xterm 16-color palette, support foreground colors (30-37) with brightness (0-1)
  -- TODO: Support background colors and other patterns
  for _, esc_pat in ipairs(ansi_16_patterns) do
    local match_x, match_y = line:sub(i):match(esc_pat)
    if match_x and match_y then
      local x, y = tonumber(match_x) or -1, tonumber(match_y) or -1
      -- Color and brightness positions are interchangeable
      local color, brightness = math.max(x, y), math.min(x, y)
      if color >= 30 and color <= 37 and brightness >= 0 and brightness <= 1 then
        color = color - 30
        return 5 + #match_x + #match_y, xterm_palette[color + 1 + brightness * 8]
      end
    end
  end
  return nil
end

--- Parser spec for the registry
M.spec = {
  name = "xterm",
  priority = 9,
  dispatch = { kind = "byte+fallback", bytes = { 0x23 } },
  config_defaults = { enable = false },
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
