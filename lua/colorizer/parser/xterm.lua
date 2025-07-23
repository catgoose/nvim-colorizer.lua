--[[-- This module provides a parser for identifying and converting xterm color codes to RGB hexadecimal format.
It supports both #xNN format (decimal, 0-255) and ANSI escape sequences \e[38;5;NNNm for xterm 256-color palette.
The function reads the color code and returns the corresponding RGB hex string from the xterm color palette.
]]
-- @module colorizer.parser.xterm
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

--- Parses xterm color codes and converts them to RGB hex format.
-- This function matches both #xNN format (decimal, 0-255) and ANSI escape sequences \e[38;5;NNNm
-- for xterm 256-color palette. It returns the corresponding RGB hex string from the xterm color palette.
---@param line string: The line of text to parse for xterm color codes
---@param i number: The starting index within the line where parsing should begin
---@return number|nil: The end index of the parsed xterm color code within the line, or `nil` if parsing failed
---@return string|nil: The RGB hexadecimal color from the xterm palette, or `nil` if parsing failed
function M.parser(line, i)
  -- #xNN (decimal, 0-255)
  local hash_x = line:sub(i, i + 1)
  if hash_x == "#x" then
    local num = line:sub(i + 2):match("^(%d?%d?%d)")
    if num then
      local idx = tonumber(num)
      if idx and idx >= 0 and idx <= 255 then
        local next_char = line:sub(i + 2 + #num, i + 2 + #num)
        if next_char == "" or not next_char:match("%w") then
          return 2 + #num, xterm_palette[idx + 1]
        end
      end
    end
  end
  -- \e[38;5;NNNm (decimal, 0-255), support both literal '\e' and actual escape char
  local ansi_patterns = {
    "^\\e%[38;5;(%d?%d?%d)m",   -- literal '\e'
    "^\27%[38;5;(%d?%d?%d)m",    -- ASCII 27
    "^\x1b%[38;5;(%d?%d?%d)m",   -- hex escape
  }
  for _, esc_pat in ipairs(ansi_patterns) do
    local esc_match = line:sub(i):match(esc_pat)
    if esc_match then
      local idx = tonumber(esc_match)
      if idx and idx >= 0 and idx <= 255 then
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
  return nil
end

return M 