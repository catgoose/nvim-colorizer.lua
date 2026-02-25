---@mod colorizer.matcher Matcher
---@brief [[
---Manages matching and parsing of color patterns in buffers.
---This module provides functions for setting up and applying color parsers
---for different color formats such as RGB, HSL, hexadecimal, and named colors.
---It uses a trie-based structure to optimize prefix-based parsing.
---@brief ]]
local M = {}

local Trie = require("colorizer.trie")
local const = require("colorizer.constants")
local min, max = math.min, math.max

local parsers = {
  color_name = require("colorizer.parser.names").parser,
  argb_hex = require("colorizer.parser.argb_hex").parser,
  hsl_function = require("colorizer.parser.hsl").parser,
  rgb_function = require("colorizer.parser.rgb").parser,
  rgba_hex = require("colorizer.parser.rgba_hex").parser,
  oklch_function = require("colorizer.parser.oklch").parser,
  --  TODO: 2024-12-21 - Should this be moved into parsers module?
  sass_name = require("colorizer.sass").parser,
  xterm = require("colorizer.parser.xterm").parser,
}

parsers.prefix = {
  ["_0x"] = parsers.argb_hex,
  ["_rgb"] = parsers.rgb_function,
  ["_rgba"] = parsers.rgb_function,
  ["_hsl"] = parsers.hsl_function,
  ["_hsla"] = parsers.hsl_function,
  ["_oklch"] = parsers.oklch_function,
}

--- Per-buffer custom parser state
local buffer_parser_state = {}

--- Get or create per-buffer state for a custom parser
---@param bufnr number
---@param parser_name string
---@return table
function M.get_buffer_parser_state(bufnr, parser_name)
  buffer_parser_state[bufnr] = buffer_parser_state[bufnr] or {}
  return buffer_parser_state[bufnr][parser_name]
end

--- Initialize per-buffer state for custom parsers
---@param bufnr number
---@param custom_parsers table List of custom parser definitions
function M.init_buffer_parser_state(bufnr, custom_parsers)
  if not custom_parsers or #custom_parsers == 0 then
    return
  end
  buffer_parser_state[bufnr] = buffer_parser_state[bufnr] or {}
  for _, parser_def in ipairs(custom_parsers) do
    if parser_def.state_factory and not buffer_parser_state[bufnr][parser_def.name] then
      buffer_parser_state[bufnr][parser_def.name] = parser_def.state_factory()
    end
  end
end

--- Clean up per-buffer custom parser state
---@param bufnr number
function M.cleanup_buffer_parser_state(bufnr)
  buffer_parser_state[bufnr] = nil
end

---Form a trie stuct with the given prefixes
---@param matchers table List of prefixes, {"rgb", "hsl"}
---@param matchers_trie table Table containing information regarding non-trie based parsers
---@param hooks? table Table of hook functions
-- hooks.disable_line_highlight: function to be called after parsing the line
---@param custom_parsers? table List of custom parser definitions
---@return function function which will just parse the line for enabled parsers
local function compile(matchers, matchers_trie, hooks, custom_parsers, opts)
  local trie = Trie(matchers_trie)

  -- Pre-build underscore-prefixed keys for trie prefix lookup
  local prefix_keys = {}
  for _, p in ipairs(matchers_trie) do
    prefix_keys[p] = "_" .. p
  end

  -- Build custom parser lookup structures
  local custom_prefix_trie_entries = {}
  local custom_prefix_parsers = {}
  local custom_byte_parsers = {}
  if custom_parsers and #custom_parsers > 0 then
    for _, parser_def in ipairs(custom_parsers) do
      if parser_def.prefixes then
        for _, pfx in ipairs(parser_def.prefixes) do
          table.insert(custom_prefix_trie_entries, pfx)
          custom_prefix_parsers[pfx] = parser_def
        end
      end
      if parser_def.prefix_bytes then
        for _, byte_val in ipairs(parser_def.prefix_bytes) do
          custom_byte_parsers[byte_val] = custom_byte_parsers[byte_val] or {}
          table.insert(custom_byte_parsers[byte_val], parser_def)
        end
      end
    end
  end

  -- Build custom prefix trie if we have custom prefixes
  local custom_trie
  if #custom_prefix_trie_entries > 0 then
    table.sort(custom_prefix_trie_entries, function(a, b) return #a > #b end)
    custom_trie = Trie(custom_prefix_trie_entries)
  end

  local function parse_fn(line, i, bufnr, line_nr)
    if
      hooks
      and hooks.disable_line_highlight
      and hooks.disable_line_highlight(line, bufnr, line_nr)
    then
      return
    end

    local byte = line:byte(i)

    -- Check custom byte-triggered parsers first
    if custom_byte_parsers[byte] then
      for _, parser_def in ipairs(custom_byte_parsers[byte]) do
        local state = buffer_parser_state[bufnr] and buffer_parser_state[bufnr][parser_def.name]
        local ctx = {
          line = line,
          col = i,
          bufnr = bufnr,
          line_nr = line_nr,
          opts = opts,
          parser_opts = parser_def,
          state = state or {},
        }
        local len, rgb_hex = parser_def.parse(ctx)
        if len and rgb_hex then
          return len, rgb_hex
        end
      end
    end

    -- prefix #
    if matchers.rgba_hex_parser then
      if byte == const.bytes.hash then
        if matchers.xterm_enabled then
          local len, rgb_hex = parsers.xterm(line, i)
          if len and rgb_hex then
            return len, rgb_hex
          end
        end
        return parsers.rgba_hex(line, i, matchers.rgba_hex_parser)
      end
    end

    -- prefix $, SASS Color names
    if matchers.sass_name_parser then
      if byte == const.bytes.dollar then
        return parsers.sass_name(line, i, bufnr)
      end
    end
    -- xterm ANSI escape: \e[38;5;NNNm
    if matchers.xterm_enabled then
      local len, rgb_hex = parsers.xterm(line, i)
      if len and rgb_hex then
        return len, rgb_hex
      end
    end

    -- Check custom prefix-triggered parsers
    if custom_trie then
      local custom_prefix = custom_trie:longest_prefix(line, i)
      if custom_prefix and custom_prefix_parsers[custom_prefix] then
        local parser_def = custom_prefix_parsers[custom_prefix]
        local state = buffer_parser_state[bufnr] and buffer_parser_state[bufnr][parser_def.name]
        local ctx = {
          line = line,
          col = i,
          bufnr = bufnr,
          line_nr = line_nr,
          opts = opts,
          parser_opts = parser_def,
          state = state or {},
        }
        local len, rgb_hex = parser_def.parse(ctx)
        if len and rgb_hex then
          return len, rgb_hex
        end
      end
    end

    -- Prefix 0x, rgba, rgb, hsla, hsl
    local prefix = trie:longest_prefix(line, i)
    if prefix then
      local fn = prefix_keys[prefix]
      if parsers.prefix[fn] then
        return parsers.prefix[fn](line, i, matchers[prefix])
      end
    end

    if matchers.color_name_parser then
      return parsers.color_name(line, i, matchers.color_name_parser)
    end

    -- Last resort: custom parsers without specific prefix/byte triggers
    if custom_parsers then
      for _, parser_def in ipairs(custom_parsers) do
        if not parser_def.prefixes and not parser_def.prefix_bytes then
          local state = buffer_parser_state[bufnr] and buffer_parser_state[bufnr][parser_def.name]
          local ctx = {
            line = line,
            col = i,
            bufnr = bufnr,
            line_nr = line_nr,
            opts = opts,
            parser_opts = parser_def,
            state = state or {},
          }
          local len, rgb_hex = parser_def.parse(ctx)
          if len and rgb_hex then
            return len, rgb_hex
          end
        end
      end
    end
  end

  return parse_fn
end

local matcher_cache
---Reset matcher cache
-- Called from colorizer.setup
function M.reset_cache()
  matcher_cache = {}
  buffer_parser_state = {}
end
do
  M.reset_cache()
end

--- Read all parser enable flags from new-format opts.
---@param opts table New-format options
---@return table flags Table of all enable_* flags
local function read_parser_flags(opts)
  local p = opts.parsers
  return {
    names = p.names.enable,
    names_lowercase = p.names.lowercase,
    names_camelcase = p.names.camelcase,
    names_uppercase = p.names.uppercase,
    names_strip_digits = p.names.strip_digits,
    names_custom = p.names.custom_hashed,
    sass = p.sass and p.sass.enable,
    tailwind_mode = p.tailwind.enable and p.tailwind.mode or false,
    RGB = p.hex.enable and p.hex.rgb,
    RGBA = p.hex.enable and p.hex.rgba,
    RRGGBB = p.hex.enable and p.hex.rrggbb,
    RRGGBBAA = p.hex.enable and p.hex.rrggbbaa,
    AARRGGBB = p.hex.enable and p.hex.aarrggbb,
    rgb = p.rgb.enable,
    hsl = p.hsl.enable,
    oklch = p.oklch.enable,
    xterm = p.xterm.enable,
    custom = p.custom and #p.custom > 0 and p.custom or nil,
    hooks = opts.hooks,
  }
end

--- Compute bitmask and cache key from parser flags.
---@param f table Parser flags from read_parser_flags
---@return number matcher_mask
---@return string|number matcher_key
local function calculate_matcher_key(f)
  -- Table-driven bitmask: each truthy flag sets one bit
  -- All values must be non-nil (use `or false`) so ipairs doesn't stop early
  local mask_flags = {
    f.names or false,
    (f.names and f.names_lowercase) or false,
    (f.names and f.names_camelcase) or false,
    (f.names and f.names_uppercase) or false,
    (f.names and f.names_strip_digits) or false,
    f.names_custom or false,
    f.RGB or false, f.RGBA or false, f.RRGGBB or false,
    f.RRGGBBAA or false, f.AARRGGBB or false,
    f.rgb or false, f.hsl or false,
    f.tailwind_mode == "normal",
    f.tailwind_mode == "lsp",
    f.tailwind_mode == "both",
    f.sass or false, f.xterm or false, f.oklch or false,
  }
  local matcher_mask = 0
  local bit_value = 1
  for _, flag in ipairs(mask_flags) do
    if flag then
      matcher_mask = matcher_mask + bit_value
    end
    bit_value = bit_value + bit_value
  end

  -- Add custom parser names to mask
  local custom_parser_key = ""
  if f.custom then
    matcher_mask = matcher_mask + bit_value
    local cp_names = {}
    for _, cp in ipairs(f.custom) do
      table.insert(cp_names, cp.name)
    end
    table.sort(cp_names)
    custom_parser_key = table.concat(cp_names, ",")
  end

  local matcher_key = f.names_custom
      and string.format("%d|%s|%s", matcher_mask, f.names_custom.hash, custom_parser_key)
    or custom_parser_key ~= ""
      and string.format("%d|%s", matcher_mask, custom_parser_key)
    or matcher_mask

  return matcher_mask, matcher_key
end

--- Build matchers table and prefix list from parser flags.
---@param f table Parser flags from read_parser_flags
---@return table matchers
---@return table matchers_prefix
local function build_matchers(f)
  local matchers = {}
  local matchers_prefix = {}
  matchers.xterm_enabled = f.xterm

  local tailwind_names = f.tailwind_mode == "normal" or f.tailwind_mode == "both"
  if f.names or f.names_custom or tailwind_names then
    matchers.color_name_parser = {}
    if f.names then
      matchers.color_name_parser.color_names = f.names
      matchers.color_name_parser.color_names_opts = {
        lowercase = f.names_lowercase,
        camelcase = f.names_camelcase,
        uppercase = f.names_uppercase,
        strip_digits = f.names_strip_digits,
      }
    end
    if f.names_custom then
      matchers.color_name_parser.names_custom = f.names_custom
    end
    if tailwind_names then
      matchers.color_name_parser.tailwind_names = tailwind_names
    end
  end

  matchers.sass_name_parser = f.sass or nil

  local valid_lengths =
    { [3] = f.RGB, [4] = f.RGBA, [6] = f.RRGGBB, [8] = f.RRGGBBAA }
  local minlen, maxlen
  for k, v in pairs(valid_lengths) do
    if v then
      minlen = minlen and min(k, minlen) or k
      maxlen = maxlen and max(k, maxlen) or k
    end
  end
  if minlen then
    matchers.rgba_hex_parser = {
      valid_lengths = valid_lengths,
      minlen = minlen,
      maxlen = maxlen,
    }
  end

  if f.AARRGGBB then
    table.insert(matchers_prefix, "0x")
  end

  -- Add CSS function prefixes based on enabled flags
  local css_function_prefixes = {
    oklch = f.oklch,
    hsla = f.hsl,
    hsl = f.hsl,
    rgba = f.rgb,
    rgb = f.rgb,
  }
  for prefix, enabled in pairs(css_function_prefixes) do
    if enabled then
      table.insert(matchers_prefix, prefix)
    end
  end

  -- Sort by length (descending) to ensure longer prefixes are checked before shorter ones
  -- This is critical for Trie matching: "hsla" must match before "hsl", "rgba" before "rgb"
  table.sort(matchers_prefix, function(a, b)
    return #a > #b
  end)
  for _, value in ipairs(matchers_prefix) do
    matchers[value] = { prefix = value }
  end

  return matchers, matchers_prefix
end

---Parse the given options and return a function with enabled parsers.
--if no parsers enabled then return false
--Do not try make the function again if it is present in the cache
---@param opts table New-format options (with opts.parsers) or legacy flat options
---@return function|boolean function which will just parse the line for enabled parsers
function M.make(opts)
  if not opts then
    return false
  end

  -- Auto-normalize legacy opts to new format at the API boundary
  if not opts.parsers then
    local cfg = require("colorizer.config")
    if cfg.is_legacy_options(opts) then
      opts = cfg.resolve_options(opts)
    else
      return false
    end
  end

  local f = read_parser_flags(opts)
  local matcher_mask, matcher_key = calculate_matcher_key(f)

  if matcher_mask == 0 then
    return false
  end

  local loop_parse_fn = matcher_cache[matcher_key]
  if loop_parse_fn then
    return loop_parse_fn
  end

  local matchers, matchers_prefix = build_matchers(f)
  loop_parse_fn = compile(matchers, matchers_prefix, f.hooks, f.custom, opts)
  matcher_cache[matcher_key] = loop_parse_fn

  return loop_parse_fn
end

return M
