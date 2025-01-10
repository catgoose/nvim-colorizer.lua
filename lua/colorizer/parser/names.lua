--- This module provides a parser that identifies named colors from a given line of text.
-- The module uses a Trie structure for efficient matching of color names to #rrggbb values
-- @module colorizer.parser.names
local M = {}

local Trie = require("colorizer.trie")
local utils = require("colorizer.utils")
local tohex = require("bit").tohex
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

--- Handles additional color names provided as a table or function.
---@param names_custom table|function|nil: Additional color names to add.
local function handle_names_custom(names_custom)
  if not names_custom then
    return
  end

  local names = {}
  if type(names_custom) == "table" then
    names = names_custom
  elseif type(names_custom) == "function" then
    local status, result = pcall(names_custom)
    if status and type(result) == "table" then
      names = result
    else
      vim.api.nvim_err_writeln(
        "Error in names_custom function: " .. (result or "Invalid return value")
      )
      return
    end
  end

  -- Add additional characters found in names_custom keys
  local chars = utils.get_non_alphanum_keys(names)
  names_cache.color_trie:additional_chars(chars)
  utils.add_additional_color_chars("names", chars)

  for name, hex in pairs(names) do
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

--- Handles Vim's color map and adds colors to the Trie and map.
local function handle_names(opts)
  for name, value in pairs(vim.api.nvim_get_color_map()) do
    if not (opts.strip_digits and name:match("%d+$")) then
      local rgb_hex = tohex(value, 6)
      if opts.lowercase then
        add_color(name:lower(), rgb_hex)
      end
      if opts.camelcase then
        add_color(name, rgb_hex)
      end
      if opts.uppercase then
        add_color(name:upper(), rgb_hex)
      end
    end
  end
end

--- Populates the Trie and map with colors based on options.
---@param opts table Configuration options for color names.
local function populate_colors(opts)
  names_cache.color_map = {}
  names_cache.color_trie = Trie()
  names_cache.color_name_minlen, names_cache.color_name_maxlen = nil, nil

  -- Add Vim's color map
  if opts.color_names then
    handle_names(opts.color_names_opts)
  end

  -- Add extra names
  if opts.names_custom then
    handle_names_custom(opts.names_custom)
  end
end

--- Parses a line to identify color names.
---@param line string: The text line to parse.
---@param i number: The index to start parsing from.
---@param opts table: Parsing options.
---@return number|nil, string|nil: Length of match and hex value if found.
function M.parser(line, i, opts)
  if not names_cache.color_trie then
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

return M
