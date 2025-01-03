--- This module provides a parser that identifies named colors from a given line of text.
-- The module uses a Trie structure for efficient matching of color names to #rrggbb values
-- @module colorizer.parser.tailwind_names
local M = {}

local Trie = require("colorizer.trie")
local utils = require("colorizer.utils")
local min, max = math.min, math.max

local names_cache
---Reset the color names cache.
-- Called from colorizer.setup
function M.reset_cache()
  names_cache = {
    color_map = {},
    color_trie = nil,
    color_name_minlen = nil,
    color_name_maxlen = nil,
  }
end
do
  M.reset_cache()
end

function M.update_color(name, val)
  if not name or not val then
    return
  end
  if names_cache.color_map[name] then
    names_cache.color_map[name] = val
  end
end

--- Internal function to add a color to the Trie and map.
---@param name string: The color name.
---@param val string: The color value in hex format.
local function add_color(name, val)
  names_cache.color_name_minlen = names_cache.color_name_minlen
      and min(#name, names_cache.color_name_minlen)
    or #name
  names_cache.color_name_maxlen = names_cache.color_name_maxlen
      and max(#name, names_cache.color_name_maxlen)
    or #name
  names_cache.color_map[name] = val
  names_cache.color_trie:insert(name)
end

--- Populates the Trie and map with Tailwind classnames
local function populate_colors()
  names_cache.color_map = {}
  names_cache.color_trie = Trie()
  names_cache.color_name_minlen, names_cache.color_name_maxlen = nil, nil

  names_cache.color_trie:additional_chars("-")
  local data = require("colorizer.data.tailwind_colors")
  for name, hex in pairs(data.colors) do
    for _, prefix in ipairs(data.prefixes) do
      --  TODO: 2024-12-31 - Add modifiers from data.tailwind_colors as config option?
      add_color(prefix .. "-" .. name, hex)
    end
  end
end

--- Parses a line to identify color names.
---@param line string: The text line to parse.
---@param i number: The index to start parsing from.
---@return number|nil, string|nil: Length of match and hex value if found.
function M.parser(line, i)
  if not names_cache.color_trie then
    populate_colors()
  end

  if
    #line < i + (names_cache.color_name_minlen or 0) - 1
    or (i > 1 and utils.byte_is_valid_colorchar(line:byte(i - 1)))
  then
    return
  end

  local prefix = names_cache.color_trie:longest_prefix(line, i)
  if prefix then
    local next_byte_index = i + #prefix
    if #line >= next_byte_index and utils.byte_is_valid_colorchar(line:byte(next_byte_index)) then
      return
    end
    return #prefix, names_cache.color_map[prefix]
  end
end

return M
