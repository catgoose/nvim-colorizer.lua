--- This module provides a parser that identifies named colors from a given line of text.
-- It supports standard color names and optional Tailwind CSS color names.
-- The module uses a Trie structure for efficient matching of color names in text.
-- @module colorizer.parser.names
local M = {}

local Trie = require("colorizer.trie")
local utils = require("colorizer.utils")
local tohex = require("bit").tohex
local min, max = math.min, math.max

-- Internal state encapsulation
local names_state = {
  color_map = {},
  color_trie = nil,
  color_name_minlen = nil,
  color_name_maxlen = nil,
  --  TODO: 2024-12-20 - Should these be configurable in settings opts?
  color_name_settings = { lowercase = true, strip_digits = false },
  tailwind_enabled = false,
}

--- Internal function to add a color to the Trie and map.
-- @param name string The color name.
-- @param value string The color value in hex format.
local function add_color(name, value)
  names_state.color_name_minlen = names_state.color_name_minlen
      and min(#name, names_state.color_name_minlen)
    or #name
  names_state.color_name_maxlen = names_state.color_name_maxlen
      and max(#name, names_state.color_name_maxlen)
    or #name
  names_state.color_map[name] = value
  names_state.color_trie:insert(name)
end

--- Handles additional color names provided as a table or function.
-- @param extra_names table|function|nil Additional color names to add.
local function handle_extra_names(extra_names)
  if not extra_names then
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

--- Populates the Trie and map with colors based on options.
-- @param opts table Configuration options for color names and Tailwind CSS.
local function populate_colors(opts)
  names_state.color_map = {}
  names_state.color_trie = Trie()
  names_state.color_name_minlen, names_state.color_name_maxlen = nil, nil

  -- Add Vim's color map
  if opts.color_names then
    for name, value in pairs(vim.api.nvim_get_color_map()) do
      if not (names_state.color_name_settings.strip_digits and name:match("%d+$")) then
        local rgb_hex = tohex(value, 6)
        add_color(name, rgb_hex)
        if names_state.color_name_settings.lowercase then
          add_color(name:lower(), rgb_hex)
        end
      end
    end
  end

  -- Add Tailwind colors
  if opts.tailwind then
    local tailwind = require("colorizer.tailwind_colors")
    for name, hex in pairs(tailwind.colors) do
      for _, prefix in ipairs(tailwind.prefixes) do
        add_color(prefix .. "-" .. name, hex)
      end
    end
  end
  names_state.tailwind_enabled = opts.tailwind

  -- Add extra names
  if opts.extra_names then
    handle_extra_names(opts.extra_names)
  end
end

--- Parses a line to identify color names.
-- @param line string The text line to parse.
-- @param i number The index to start parsing from.
-- @param opts table Parsing options.
-- @return number|nil, string|nil Length of match and hex value if found.
function M.parser(line, i, opts)
  if not names_state.color_trie or opts.tailwind ~= names_state.tailwind_enabled then
    populate_colors(opts)
  end

  if
    #line < i + (names_state.color_name_minlen or 0) - 1
    or (i > 1 and utils.byte_is_valid_colorchar(line:byte(i - 1)))
  then
    return
  end

  local prefix = names_state.color_trie:longest_prefix(line, i)
  if prefix then
    local next_byte_index = i + #prefix
    if #line >= next_byte_index and utils.byte_is_valid_colorchar(line:byte(next_byte_index)) then
      return
    end
    return #prefix, names_state.color_map[prefix]
  end
end

function M.reset()
  names_state = {
    color_map = {},
    color_trie = nil,
    color_name_minlen = nil,
    color_name_maxlen = nil,
    color_name_settings = { lowercase = true, strip_digits = false },
    tailwind_enabled = false,
  }
end

return M
