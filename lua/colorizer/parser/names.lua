--[[-- This module provides a parser that identifies named colors from a given line of text.
It uses a Trie structure for efficient prefix-based matching of color names to #rrggbb values.
The module supports multiple namespaces, enabling flexible configuration and handling of
different types of color names (e.g., lowercase, uppercase, camelcase, custom names, Tailwind names).

Namespaces:
<pre>
- lowercase: Contains color names converted to lowercase (e.g., "red" -> "#ff0000").
- uppercase: Contains color names converted to uppercase (e.g., "RED" -> "#ff0000").
- camelcase: Contains color names in camel case (e.g., "LightBlue" -> "#add8e6").
- tailwind_names: Contains color names based on TailwindCSS conventions, including prefixes.
- names_custom: Contains user-defined color names, either as a table or a function returning a table.</pre>

The parser dynamically populates the Trie and namespaces based on the provided options.
Unused namespaces are left empty, avoiding unnecessary memory usage. Color name matching respects
the configured namespaces and user-defined preferences, such as whether to strip digits.
]]
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
    color_map = {
      lowercase = {},
      uppercase = {},
      camelcase = {},
      tailwind_names = {},
      names_custom = {},
    },
    trie = nil,
    -- The `name_minlen` and `name_maxlen` are calculated globally across all namespaces
    -- because the Trie lookup operates independently of namespaces. Namespaces are only
    -- used for final validation after the Trie finds a match.
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
---@param hash? string: Use namespace hash key
local function add_color(name, val, namespace, hash)
  local nc = names_cache
  nc.name_minlen = nc.name_minlen and min(#name, nc.name_minlen) or #name
  nc.name_maxlen = nc.name_maxlen and max(#name, nc.name_maxlen) or #name
  local tbl = hash and nc.color_map[namespace][hash] or nc.color_map[namespace]
  tbl[name] = val
  nc.trie:insert(name)
end

--- Handles Vim's color map and adds colors to the Trie and map.
local function populate_names(color_names_opts)
  for name, value in pairs(vim.api.nvim_get_color_map()) do
    local rgb_hex = tohex(value, 6)
    if color_names_opts.lowercase then
      add_color(name:lower(), rgb_hex, "lowercase")
    end
    if color_names_opts.camelcase then
      add_color(name, rgb_hex, "camelcase")
    end
    if color_names_opts.uppercase then
      add_color(name:upper(), rgb_hex, "uppercase")
    end
  end
end

--- Adds custom color names provided by user
local function populate_names_custom(names_custom)
  if not (names_custom.hash and names_custom.names) then
    return
  end
  -- Add additional characters found in names_custom keys
  local chars = utils.get_non_alphanum_keys(names_custom.names)
  utils.add_additional_color_chars(chars)
  -- Initialize hash key
  local hash = names_custom.hash
  if hash then
    names_cache.color_map.names_custom[hash] = names_cache.color_map.names_custom[hash] or {}
  end
  for name, hex in pairs(names_custom.names) do
    if type(hex) == "string" then
      local normalized_hex = hex:gsub("^#", ""):gsub("%s", "")
      if normalized_hex:match("^%x%x%x%x%x%x$") then
        add_color(name, normalized_hex, "names_custom", hash)
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
---@param m_opts table Configuration options for color names.
local function populate_colors(m_opts)
  if not names_cache.trie then
    names_cache.trie = Trie()
  end
  names_cache.name_minlen = names_cache.name_minlen or nil
  names_cache.name_maxlen = names_cache.name_maxlen or nil
  -- Add Vim's color map
  if m_opts.color_names then
    populate_names(m_opts.color_names_opts)
  end
  -- Add custom names
  if m_opts.names_custom then
    populate_names_custom(m_opts.names_custom)
  end
  -- Add tailwind names
  if m_opts.tailwind_names then
    populate_tailwind_names()
  end
end

local function get_color_entry(namespace, prefix, options)
  local color_entry = names_cache.color_map[namespace][prefix]
  if color_entry and not (options.strip_digits and prefix:match("%d+$")) then
    return color_entry
  end
end

local function resolve_color_entry(prefix, m_opts)
  -- Check namespaces based on m_opts
  if m_opts.color_names then
    local opts = m_opts.color_names_opts
    if opts.lowercase then
      local color_entry = get_color_entry("lowercase", prefix, opts)
      if color_entry then
        return color_entry
      end
    end
    if opts.uppercase then
      local color_entry = get_color_entry("uppercase", prefix, opts)
      if color_entry then
        return color_entry
      end
    end
    if opts.camelcase then
      local color_entry = get_color_entry("camelcase", prefix, opts)
      if color_entry then
        return color_entry
      end
    end
  end
  -- Handle names_custom with a hash
  if m_opts.names_custom and m_opts.names_custom.hash then
    local custom_map = names_cache.color_map.names_custom[m_opts.names_custom.hash]
    if custom_map then
      local color_entry = custom_map[prefix]
      if color_entry then
        return color_entry
      end
    end
  end
  -- Handle tailwind_names
  if m_opts.tailwind_names then
    local color_entry = names_cache.color_map.tailwind_names[prefix]
    if color_entry then
      return color_entry
    end
  end
end

local function needs_population(m_opts)
  local cm = names_cache.color_map
  if m_opts.color_names then
    local cn_opts = m_opts.color_names_opts
    if cn_opts.lowercase and not next(cm.lowercase) then
      return true
    end
    if cn_opts.uppercase and not next(cm.uppercase) then
      return true
    end
    if cn_opts.camelcase and not next(cm.camelcase) then
      return true
    end
  end
  if m_opts.tailwind_names and not next(cm.tailwind_names) then
    return true
  end
  if
    m_opts.names_custom
    and m_opts.names_custom.hash
    and not cm.names_custom[m_opts.names_custom.hash]
  then
    return true
  end
end

--- Parses a line to identify color names.
---@param line string: The text line to parse.
---@param i number: The index to start parsing from.
---@param m_opts table: Matcher opts
---@return number|nil, string|nil: Length of match and hex value if found.
function M.parser(line, i, m_opts)
  if not names_cache.trie or needs_population(m_opts) then
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
    -- if prefix is found in trie, check if the color name to rgb map exists for enabled namespaces
    local color_entry = resolve_color_entry(prefix, m_opts)
    if color_entry then
      return #prefix, color_entry
    end
  end
end

return M
