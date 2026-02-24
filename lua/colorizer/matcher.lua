---@mod colorizer.matcher Matcher
---@brief [[
---Manages matching and parsing of color patterns in buffers.
---This module provides functions for setting up and applying color parsers
---for different color formats such as RGB, HSL, hexadecimal, and named colors.
---It uses a trie-based structure to optimize prefix-based parsing.
---@brief ]]
local M = {}

local Trie = require("colorizer.trie")
local min, max = math.min, math.max

local BYTE_HASH = 0x23   -- string.byte("#")
local BYTE_DOLLAR = 0x24 -- string.byte("$")

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
local function compile(matchers, matchers_trie, hooks, custom_parsers)
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
      if byte == BYTE_HASH then
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
      if byte == BYTE_DOLLAR then
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

---Parse the given options and return a function with enabled parsers.
--if no parsers enabled then return false
--Do not try make the function again if it is present in the cache
---@param opts table New-format options (with opts.parsers) or legacy flat ud_opts
---@return function|boolean function which will just parse the line for enabled parsers
function M.make(opts)
  if not opts then
    return false
  end

  -- Read from new format (opts.parsers.*) or fall back to legacy flat keys
  local p = opts.parsers
  local enable_names, enable_names_lowercase, enable_names_camelcase
  local enable_names_uppercase, enable_names_strip_digits, enable_names_custom
  local enable_sass, enable_tailwind, enable_tailwind_mode
  local enable_RGB, enable_RGBA, enable_RRGGBB, enable_RRGGBBAA, enable_AARRGGBB
  local enable_rgb, enable_hsl, enable_oklch, enable_xterm
  local custom_parsers, hooks

  if p then
    -- New format
    enable_names = p.names.enable
    enable_names_lowercase = p.names.lowercase
    enable_names_camelcase = p.names.camelcase
    enable_names_uppercase = p.names.uppercase
    enable_names_strip_digits = p.names.strip_digits
    enable_names_custom = p.names.custom_hashed
    enable_sass = p.sass and p.sass.enable
    enable_tailwind = p.tailwind.enable
    enable_tailwind_mode = p.tailwind.enable and p.tailwind.mode or false
    enable_RGB = p.hex.enable and p.hex.rgb
    enable_RGBA = p.hex.enable and p.hex.rgba
    enable_RRGGBB = p.hex.enable and p.hex.rrggbb
    enable_RRGGBBAA = p.hex.enable and p.hex.rrggbbaa
    enable_AARRGGBB = p.hex.enable and p.hex.aarrggbb
    enable_rgb = p.rgb.enable
    enable_hsl = p.hsl.enable
    enable_oklch = p.oklch.enable
    enable_xterm = p.xterm.enable
    custom_parsers = p.custom and #p.custom > 0 and p.custom or nil
    hooks = opts.hooks
  else
    -- Legacy flat format (backward compat)
    enable_names = opts.names
    enable_names_lowercase = opts.names_opts and opts.names_opts.lowercase
    enable_names_camelcase = opts.names_opts and opts.names_opts.camelcase
    enable_names_uppercase = opts.names_opts and opts.names_opts.uppercase
    enable_names_strip_digits = opts.names_opts and opts.names_opts.strip_digits
    enable_names_custom = opts.names_custom_hashed
    enable_sass = opts.sass and opts.sass.enable
    enable_tailwind = opts.tailwind and opts.tailwind ~= false
    enable_tailwind_mode = opts.tailwind
    enable_RGB = opts.RGB
    enable_RGBA = opts.RGBA
    enable_RRGGBB = opts.RRGGBB
    enable_RRGGBBAA = opts.RRGGBBAA
    enable_AARRGGBB = opts.AARRGGBB
    enable_rgb = opts.rgb_fn
    enable_hsl = opts.hsl_fn
    enable_oklch = opts.oklch_fn
    enable_xterm = opts.xterm
    hooks = opts.hooks
  end

  -- Rather than use bit.lshift or calculate 2^x, use precalculated values to
  -- create unique bitmask
  local matcher_mask = 0
    + (enable_names and 1 or 0)
    + (enable_names and enable_names_lowercase and 2 or 0)
    + (enable_names and enable_names_camelcase and 4 or 0)
    + (enable_names and enable_names_uppercase and 8 or 0)
    + (enable_names and enable_names_strip_digits and 16 or 0)
    + (enable_names_custom and 32 or 0)
    + (enable_RGB and 64 or 0)
    + (enable_RGBA and 128 or 0)
    + (enable_RRGGBB and 256 or 0)
    + (enable_RRGGBBAA and 512 or 0)
    + (enable_AARRGGBB and 1024 or 0)
    + (enable_rgb and 2048 or 0)
    + (enable_hsl and 4096 or 0)
    + (enable_tailwind_mode == "normal" and 8192 or 0)
    + (enable_tailwind_mode == "lsp" and 16384 or 0)
    + (enable_tailwind_mode == "both" and 32768 or 0)
    + (enable_sass and 65536 or 0)
    + (enable_xterm and 131072 or 0)
    + (enable_oklch and 262144 or 0)

  -- Add custom parser names to mask
  local custom_parser_key = ""
  if custom_parsers then
    matcher_mask = matcher_mask + 524288
    local names = {}
    for _, cp in ipairs(custom_parsers) do
      table.insert(names, cp.name)
    end
    table.sort(names)
    custom_parser_key = table.concat(names, ",")
  end

  if matcher_mask == 0 then
    return false
  end

  local matcher_key = enable_names_custom
      and string.format("%d|%s|%s", matcher_mask, enable_names_custom.hash, custom_parser_key)
    or custom_parser_key ~= ""
      and string.format("%d|%s", matcher_mask, custom_parser_key)
    or matcher_mask

  local loop_parse_fn = matcher_cache[matcher_key]
  if loop_parse_fn then
    return loop_parse_fn
  end

  local matchers = {}
  local matchers_prefix = {}
  matchers.xterm_enabled = enable_xterm

  local enable_tailwind_names = enable_tailwind_mode == "normal" or enable_tailwind_mode == "both"
  if enable_names or enable_names_custom or enable_tailwind_names then
    matchers.color_name_parser = matchers.color_name_parser or {}
    if enable_names then
      matchers.color_name_parser.color_names = enable_names
      matchers.color_name_parser.color_names_opts = {
        lowercase = enable_names_lowercase,
        camelcase = enable_names_camelcase,
        uppercase = enable_names_uppercase,
        strip_digits = enable_names_strip_digits,
      }
    end
    if enable_names_custom then
      matchers.color_name_parser.names_custom = enable_names_custom
    end
    if enable_tailwind_names then
      matchers.color_name_parser.tailwind_names = enable_tailwind_names
    end
  end

  matchers.sass_name_parser = enable_sass or nil

  local valid_lengths =
    { [3] = enable_RGB, [4] = enable_RGBA, [6] = enable_RRGGBB, [8] = enable_RRGGBBAA }
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

  --  TODO: 2024-11-05 - Add custom prefixes
  if enable_AARRGGBB then
    table.insert(matchers_prefix, "0x")
  end

  -- Add CSS function prefixes based on enabled flags
  -- Will be sorted by length to ensure correct Trie matching (longer prefixes first)
  local css_function_prefixes = {
    oklch = enable_oklch,
    hsla = enable_hsl,
    hsl = enable_hsl,
    rgba = enable_rgb,
    rgb = enable_rgb,
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

  loop_parse_fn = compile(matchers, matchers_prefix, hooks, custom_parsers)
  matcher_cache[matcher_key] = loop_parse_fn

  return loop_parse_fn
end

return M
