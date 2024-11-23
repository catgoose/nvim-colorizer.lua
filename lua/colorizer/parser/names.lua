--- This module provides a parser that identifies named colors from a given line of text.
-- It supports standard color names and optional Tailwind CSS color names.
-- The module creates a lookup table and Trie structure to efficiently match color names in text.
--@module colorizer.parser.names
local M = {}

local Trie = require("colorizer.trie")
local utils = require("colorizer.utils")
local tohex = require("bit").tohex
local min, max = math.min, math.max

local color_map = {}
local color_trie = Trie()
local color_name_minlen, color_name_maxlen
local color_name_settings = { lowercase = true, strip_digits = false }
local tailwind_enabled = false

--- Internal function to add colors to the trie and color map
---@param name string: The color name
---@param value string: The color value in hex
local function add_color(name, value)
  color_name_minlen = color_name_minlen and min(#name, color_name_minlen) or #name
  color_name_maxlen = color_name_maxlen and max(#name, color_name_maxlen) or #name
  color_map[name] = value
  color_trie:insert(name)
end

--- Add extra names to the color map
---@param extra_names boolean|table|function|nil: Additional color names to process
local function handle_extra_names(extra_names)
  if not extra_names or extra_names == false then
    return
  end

  local extra_data = {}

  if type(extra_names) == "table" then
    extra_data = extra_names
  elseif type(extra_names) == "function" then
    local status, result = pcall(extra_names)
    if status and type(result) == "table" then
      extra_data = result
    else
      vim.api.nvim_err_writeln(
        "Error in extra_names function: " .. (result or "Invalid return value")
      )
      return
    end
  end

  -- Normalize hex values and add to the color map
  for k, v in pairs(extra_data) do
    if type(v) == "string" then
      local normalized_hex = v:gsub("^#", "") -- Remove leading #
      add_color(k, normalized_hex)
    else
      vim.api.nvim_err_writeln(
        "Invalid value for color name '" .. k .. "': Expected a string, got " .. type(v)
      )
    end
  end
end

--- Populate colors from the provided sources
---@param opts table: Options for tailwind and extra names
local function populate_colors(opts)
  color_map = {}
  color_trie = Trie()
  color_name_minlen, color_name_maxlen = nil, nil

  -- Add colors from Vim's color map
  if opts.color_names then
    for k, v in pairs(vim.api.nvim_get_color_map()) do
      if not (color_name_settings.strip_digits and k:match("%d+$")) then
        local rgb_hex = tohex(v, 6)
        add_color(k, rgb_hex)
        if color_name_settings.lowercase then
          add_color(k:lower(), rgb_hex)
        end
      end
    end
  end

  -- Add Tailwind colors if enabled
  if opts.tailwind then
    local tailwind = require("colorizer.tailwind_colors")
    for k, v in pairs(tailwind.colors) do
      for _, pre in ipairs(tailwind.prefixes) do
        add_color(pre .. "-" .. k, v)
      end
    end
  end
  tailwind_enabled = opts.tailwind

  --  BUG: 2024-11-23 - `names` color is matching `extra_names`
  -- Handle extra names
  if opts.extra_names then
    handle_extra_names(opts.extra_names)
  end
end

--- Parse a line to find color names
---@param line string: Line to parse
---@param i number: Index of line from where to start parsing
---@param opts table: Parsing options
---@return number|nil, string|nil: Length of match and hex value if found
function M.name_parser(line, i, opts)
  if not color_trie or opts.tailwind ~= tailwind_enabled then
    populate_colors(opts)
  end

  if
    #line < i + (color_name_minlen or 0) - 1
    or (i > 1 and utils.byte_is_valid_colorchar(line:byte(i - 1)))
  then
    return
  end

  local prefix = color_trie:longest_prefix(line, i)
  if prefix then
    local next_byte_index = i + #prefix
    if #line >= next_byte_index and utils.byte_is_valid_colorchar(line:byte(next_byte_index)) then
      return
    end
    return #prefix, color_map[prefix]
  end
end

return M.name_parser
