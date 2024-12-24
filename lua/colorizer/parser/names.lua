--- This module provides a parser that identifies named colors from a given line of text.
-- It supports standard color names and optional Tailwind CSS color names.
-- The module uses a Trie structure for efficient matching of color names in text.
-- @module colorizer.parser.names
local M = {}

local Trie = require("colorizer.trie")
local utils = require("colorizer.utils")
local tohex = require("bit").tohex
local min, max = math.min, math.max

local names_cache = {
  color_map = {},
  color_trie = nil,
  color_name_minlen = nil,
  color_name_maxlen = nil,
  color_name_settings = { lowercase = true, strip_digits = false },
  tailwind_enabled = false,
}

--- Internal function to add a color to the Trie and map.
-- @param name string The color name.
-- @param value string The color value in hex format.
local function add_color(name, value)
  names_cache.color_name_minlen = names_cache.color_name_minlen
      and min(#name, names_cache.color_name_minlen)
    or #name
  names_cache.color_name_maxlen = names_cache.color_name_maxlen
      and max(#name, names_cache.color_name_maxlen)
    or #name
  names_cache.color_map[name] = value
  names_cache.color_trie:insert(name)
end

--- Extract non-alphanumeric characters to add as a valid index in the Trie
-- @param tbl table The table to extract non-alphanumeric characters from.
local function extract_non_alphanum_keys(tbl)
  local non_alphanum_chars = {}
  for key, _ in pairs(tbl) do
    for char in key:gmatch("[^%w]") do
      non_alphanum_chars[char] = true
    end
  end
  local result = ""
  for char in pairs(non_alphanum_chars) do
    result = result .. char
  end
  return result
end

--- Handles additional color names provided as a table or function.
-- @param names_custom table|function|nil Additional color names to add.
local function handle_names_custom(names_custom)
  if not names_custom then
    return
  end

  local extra_data = {}
  if type(names_custom) == "table" then
    extra_data = names_custom
  elseif type(names_custom) == "function" then
    local status, result = pcall(names_custom)
    if status and type(result) == "table" then
      extra_data = result
    else
      vim.api.nvim_err_writeln(
        "Error in names_custom function: " .. (result or "Invalid return value")
      )
      return
    end
  end

  -- Add additional characters found in names_custom keys
  local additonal_chars = extract_non_alphanum_keys(extra_data)
  names_cache.color_trie:additional_chars(additonal_chars)

  for name, hex in pairs(extra_data) do
    if type(hex) == "string" then
      local normalized_hex = hex:gsub("^#", ""):gsub("%s", "")
      if normalized_hex:match("^%x%x%x%x%x%x$") then
        add_color(name, normalized_hex)
      else
        vim.api.nvim_err_writeln("Invalid hex code for '" .. name .. "': " .. normalized_hex)
      end
    else
      vim.api.nvim_err_writeln(
        "Invalid value for '" .. name .. "': Expected string, got " .. type(hex)
      )
    end
  end
end

--- Handles Tailwind CSS colors and adds them to the Trie and map.
local function handle_tailwind()
  names_cache.color_trie:additional_chars("-")
  local tailwind = require("colorizer.tailwind_colors")
  for name, hex in pairs(tailwind.colors) do
    for _, prefix in ipairs(tailwind.prefixes) do
      add_color(prefix .. "-" .. name, hex)
    end
  end
end

--- Handles Vim's color map and adds colors to the Trie and map.
local function handle_names()
  for name, value in pairs(vim.api.nvim_get_color_map()) do
    if not (names_cache.color_name_settings.strip_digits and name:match("%d+$")) then
      local rgb_hex = tohex(value, 6)
      add_color(name, rgb_hex)
      if names_cache.color_name_settings.lowercase then
        add_color(name:lower(), rgb_hex)
      end
    end
  end
end

--- Populates the Trie and map with colors based on options.
-- @param opts table Configuration options for color names and Tailwind CSS.
local function populate_colors(opts)
  names_cache.color_map = {}
  names_cache.color_trie = Trie()
  names_cache.color_name_minlen, names_cache.color_name_maxlen = nil, nil

  -- Add Vim's color map
  if opts.color_names then
    handle_names()
  end

  -- Add Tailwind colors
  if opts.tailwind then
    handle_tailwind()
  end
  names_cache.tailwind_enabled = opts.tailwind

  -- Add extra names
  if opts.names_custom then
    handle_names_custom(opts.names_custom)
  end
end

--- Parses a line to identify color names.
-- @param line string The text line to parse.
-- @param i number The index to start parsing from.
-- @param opts table Parsing options.
-- @return number|nil, string|nil Length of match and hex value if found.
function M.parser(line, i, opts)
  if not names_cache.color_trie or opts.tailwind ~= names_cache.tailwind_enabled then
    --  TODO: 2024-12-21 - Ensure that this is not being called too many times
    populate_colors(opts)
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

---Resets the color names cache.
---Called from colorizer.setup
function M.reset_cache()
  names_cache = {
    color_map = {},
    color_trie = nil,
    color_name_minlen = nil,
    color_name_maxlen = nil,
    color_name_settings = { lowercase = true, strip_digits = false },
    tailwind_enabled = false,
  }
end

return M
