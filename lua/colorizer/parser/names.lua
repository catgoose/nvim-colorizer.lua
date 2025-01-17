--- This module provides a parser that identifies named colors from a given line of text.
-- It uses a Trie structure for efficient prefix-based matching of color names to #rrggbb values.
-- The module supports multiple namespaces, enabling flexible configuration and handling of
-- different types of color names (e.g., lowercase, uppercase, camelcase, custom names, Tailwind names).
--
-- Namespaces:
-- <pre>
-- - lowercase: Contains color names converted to lowercase (e.g., "red" -> "#ff0000").
-- - uppercase: Contains color names converted to uppercase (e.g., "RED" -> "#ff0000").
-- - camelcase: Contains color names in camel case (e.g., "LightBlue" -> "#add8e6").
-- - tailwind_names: Contains color names based on TailwindCSS conventions, including prefixes.
-- - names_custom: Contains user-defined color names, either as a table or a function returning a table.</pre>
--
-- The parser dynamically populates the Trie and namespaces based on the provided options.
-- Unused namespaces are left empty, avoiding unnecessary memory usage. Color name matching respects
-- the configured namespaces and user-defined preferences, such as whether to strip digits.
--
-- @module colorizer.parser.names
local M = {}

local Trie = require("colorizer.trie")
local utils = require("colorizer.utils")
local tohex = require("bit").tohex
local min, max = math.min, math.max

local namespace_list = { "lowercase", "uppercase", "camelcase", "tailwind_names", "names_custom" }

local names_cache
---Reset the color names cache.
-- Called from colorizer.setup
function M.reset_cache()
  names_cache = {
    color_map = {
      lowercase = {},
      uppercase = {},
      camelcase = {},
      tailwind_names = {},
      names_custom = {},
    },
    trie = nil,
    -- TODO: 2025-01-16 - Should name_{min|max}len be stored in each color_map namespace?
    name_minlen = nil,
    name_maxlen = nil,
  }
end
do
  M.reset_cache()
end

--- Updates the color value for a given color name.
---@param name string: The color name.
---@param hex string: The color value in hex format.
---@param namespace string: The color map namespace.
function M.update_color(name, hex, namespace)
  if not name or not hex then
    return
  end
  names_cache.color_map[namespace] = names_cache.color_map[namespace] or {} -- is this required?
  if names_cache.color_map[namespace][name] then
    names_cache.color_map[namespace][name] = hex
  end
end

--- Internal function to add a color to the Trie and map.
---@param name string: The color name.
---@param val string: The color value in hex format.
---@param namespace string: The color map namespace.
local function add_color(name, val, namespace)
  names_cache.name_minlen = names_cache.name_minlen and min(#name, names_cache.name_minlen) or #name
  names_cache.name_maxlen = names_cache.name_maxlen and max(#name, names_cache.name_maxlen) or #name
  names_cache.color_map[namespace][name] = val
  names_cache.trie:insert(name)
end

--- Handles Vim's color map and adds colors to the Trie and map.
local function populate_names(matcher_opts)
  for name, value in pairs(vim.api.nvim_get_color_map()) do
    local rgb_hex = tohex(value, 6)
    if matcher_opts.lowercase then
      add_color(name:lower(), rgb_hex, "lowercase")
    end
    if matcher_opts.camelcase then
      add_color(name, rgb_hex, "camelcase")
    end
    if matcher_opts.uppercase then
      add_color(name:upper(), rgb_hex, "uppercase")
    end
  end
end

--- Handles additional color names provided as a table or function.
---@param names_custom table|function|nil: Additional color names to add.
local function populate_names_custom(names_custom)
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
      utils.log_message("Error in names_custom function: " .. (result or "Invalid return value"))
      return
    end
  end
  -- Add additional characters found in names_custom keys
  local chars = utils.get_non_alphanum_keys(names)
  utils.add_additional_color_chars(chars)
  for name, hex in pairs(names) do
    if type(hex) == "string" then
      local normalized_hex = hex:gsub("^#", ""):gsub("%s", "")
      if normalized_hex:match("^%x%x%x%x%x%x$") then
        add_color(name, normalized_hex, "names_custom")
      else
        utils.log_message(string.format("Invalid hex code for '%s': %s", name, normalized_hex))
      end
    else
      utils.log_message(
        string.format("Invalid value for '%s': Expected string, got %s", name, type(hex))
      )
    end
  end
end

--- Handles Tailwind classnames and adds colors to the Trie and map.
local function populate_tailwind_names()
  local tw_delimeter = "-"
  utils.add_additional_color_chars(tw_delimeter)
  local data = require("colorizer.data.tailwind_colors")
  for name, hex in pairs(data.colors) do
    for _, prefix in ipairs(data.prefixes) do
      add_color(string.format("%s%s%s", prefix, tw_delimeter, name), hex, "tailwind_names")
    end
  end
end

--- Populates the Trie and map with colors based on options.
---@param opts table Configuration options for color names.
local function populate_colors(opts)
  if not names_cache.trie then
    names_cache.trie = Trie()
  end
  names_cache.name_minlen = names_cache.name_minlen or nil
  names_cache.name_maxlen = names_cache.name_maxlen or nil
  -- Add Vim's color map
  if opts.color_names then
    populate_names(opts.color_names_opts)
  end
  -- Add custom names
  if opts.names_custom then
    populate_names_custom(opts.names_custom)
  end
  -- Add tailwind names
  if opts.tailwind_names then
    populate_tailwind_names()
  end
end

local function resolve_color_entry(prefix, m_opts)
  local namespace_lookup = {
    {
      key = "lowercase",
      enabled = m_opts.color_names and m_opts.color_names_opts.lowercase,
      vimcolor = true,
    },
    {
      key = "uppercase",
      enabled = m_opts.color_names and m_opts.color_names_opts.uppercase,
      vimcolor = true,
    },
    {
      key = "camelcase",
      enabled = m_opts.color_names and m_opts.color_names_opts.camelcase,
      vimcolor = true,
    },
    {
      key = "names_custom",
      enabled = m_opts.names_custom,
      vimcolor = false,
    },
    {
      key = "tailwind_names",
      enabled = m_opts.tailwind_names,
      vimcolor = false,
    },
  }
  for _, nsl in ipairs(namespace_lookup) do
    if nsl.enabled then
      local color_entry = names_cache.color_map[nsl.key] and names_cache.color_map[nsl.key][prefix]
      if
        color_entry
        and not (nsl.vimcolor and m_opts.color_names_opts.strip_digits and prefix:match("%d+$"))
      then
        return color_entry
      end
    end
  end
end

local function needs_population(m_opts)
  for _, ns in ipairs(namespace_list) do
    if
      (ns == "lowercase" or ns == "uppercase" or ns == "camelcase")
        and m_opts.color_names_opts[ns]
        and not next(names_cache.color_map[ns])
      or (ns == "tailwind_names" or ns == "names_custom")
        and m_opts[ns]
        and not next(names_cache.color_map[ns])
    then
      return true
    end
  end
end

--- Parses a line to identify color names.
---@param line string: The text line to parse.
---@param i number: The index to start parsing from.
---@param m_opts table: Matcher opts
---@return number|nil, string|nil: Length of match and hex value if found.
function M.parser(line, i, m_opts)
  if not names_cache.trie or (needs_population(m_opts)) then
    populate_colors(m_opts)
  end

  if
    #line < i + (names_cache.name_minlen or 0) - 1
    or (i > 1 and utils.byte_is_valid_color_char(line:byte(i - 1)))
  then
    -- early return if the line is too short or the previous character is a color char
    return
  end

  local prefix = names_cache.trie:longest_prefix(line, i)
  if prefix then
    local next_byte_index = i + #prefix
    if #line >= next_byte_index and utils.byte_is_valid_color_char(line:byte(next_byte_index)) then
      -- early return if next byte is not a valid color character
      return
    end
    -- if prefix is found in try, check if the color name to rgb map exists for enabled namespaces
    local color_entry = resolve_color_entry(prefix, m_opts)
    if color_entry then
      return #prefix, color_entry
    end
  end
end

return M
