--- This module provides a parser that identifies named colors from a given line of text.
-- It supports standard color names and optional Tailwind CSS color names.
-- The module creates a lookup table and Trie structure to efficiently match color names in text.
--@module colorizer.parser.names
local M = {}

local Trie = require("colorizer.trie")
local utils = require("colorizer.utils")
local tohex = require("bit").tohex
local min, max = math.min, math.max

local color_map
local color_trie
local color_name_minlen, color_name_maxlen
local color_name_settings = { lowercase = true, strip_digits = false }
local tailwind_enabled = false

--- Grab all the color values from `vim.api.nvim_get_color_map` and create a lookup table.
-- color_map is used to store the color values
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@param opts table: Currently contains whether tailwind is enabled or not
function M.name_parser(line, i, opts)
  --- Setup the color_map and color_trie
  if not color_trie or opts.tailwind ~= tailwind_enabled then
    color_map = {}
    color_trie = Trie()
    for k, v in pairs(vim.api.nvim_get_color_map()) do
      if not (color_name_settings.strip_digits and k:match("%d+$")) then
        color_name_minlen = color_name_minlen and min(#k, color_name_minlen) or #k
        color_name_maxlen = color_name_maxlen and max(#k, color_name_maxlen) or #k
        local rgb_hex = tohex(v, 6)
        color_map[k] = rgb_hex
        color_trie:insert(k)
        if color_name_settings.lowercase then
          local lowercase = k:lower()
          color_map[lowercase] = rgb_hex
          color_trie:insert(lowercase)
        end
      end
    end
    if opts and opts.tailwind then
      if opts.tailwind == true or opts.tailwind == "normal" or opts.tailwind == "both" then
        local tailwind = require("colorizer.tailwind_colors")
        -- setup tailwind colors
        for k, v in pairs(tailwind.colors) do
          for _, pre in ipairs(tailwind.prefixes) do
            local name = pre .. "-" .. k
            color_name_minlen = color_name_minlen and min(#name, color_name_minlen) or #name
            color_name_maxlen = color_name_maxlen and max(#name, color_name_maxlen) or #name
            color_map[name] = v
            color_trie:insert(name)
          end
        end
      end
    end
    tailwind_enabled = opts.tailwind
  end

  if #line < i + color_name_minlen - 1 then
    return
  end

  if i > 1 and utils.byte_is_valid_colorchar(line:byte(i - 1)) then
    return
  end

  local prefix = color_trie:longest_prefix(line, i)
  if prefix then
    -- Check if there is a letter here so as to disallow matching here.
    -- Take the Blue out of Blueberry
    -- Line end or non-letter.
    local next_byte_index = i + #prefix
    if #line >= next_byte_index and utils.byte_is_valid_colorchar(line:byte(next_byte_index)) then
      return
    end
    return #prefix, color_map[prefix]
  end
end

return M.name_parser
