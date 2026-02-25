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

-- Load all parsers into the registry
local registry = require("colorizer.parser")

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

--- Check if a registered parser is enabled given the current opts.
---@param spec colorizer.ParserSpec
---@param opts table New-format options
---@return boolean
local function is_parser_enabled(spec, opts)
  local p = opts.parsers

  if spec.name == "rgba_hex" then
    -- Controlled by hex.* composite config
    if not (p.hex and p.hex.enable) then
      return false
    end
    return p.hex.rgb or p.hex.rgba or p.hex.rrggbb or p.hex.rrggbbaa or false
  elseif spec.name == "argb_hex" then
    return p.hex and p.hex.enable and p.hex.aarrggbb or false
  elseif spec.name == "names" then
    local tw = p.tailwind
    local tailwind_names = tw and tw.enable and (tw.mode == "normal" or tw.mode == "both")
    return (p.names and p.names.enable) or (p.names and p.names.custom_hashed) or tailwind_names or false
  else
    local parser_opts = p[spec.name]
    if parser_opts and type(parser_opts) == "table" then
      return parser_opts.enable or false
    end
    return false
  end
end

--- Build parser_config and matcher_opts for a registered parser.
---@param spec colorizer.ParserSpec
---@param opts table New-format options
---@return table|nil parser_config
---@return table|nil matcher_opts
local function build_entry_config(spec, opts)
  local p = opts.parsers

  if spec.name == "rgba_hex" then
    local valid_lengths = {
      [3] = p.hex.rgb,
      [4] = p.hex.rgba,
      [6] = p.hex.rrggbb,
      [8] = p.hex.rrggbbaa,
    }
    local minlen, maxlen
    for k, v in pairs(valid_lengths) do
      if v then
        minlen = minlen and min(k, minlen) or k
        maxlen = maxlen and max(k, maxlen) or k
      end
    end
    return { valid_lengths = valid_lengths, minlen = minlen, maxlen = maxlen }, nil
  elseif spec.name == "names" then
    local m_opts = {}
    if p.names and p.names.enable then
      m_opts.color_names = true
      m_opts.color_names_opts = {
        lowercase = p.names.lowercase,
        camelcase = p.names.camelcase,
        uppercase = p.names.uppercase,
        strip_digits = p.names.strip_digits,
      }
    end
    if p.names and p.names.custom_hashed then
      m_opts.names_custom = p.names.custom_hashed
    end
    local tw = p.tailwind
    if tw and tw.enable and (tw.mode == "normal" or tw.mode == "both") then
      m_opts.tailwind_names = true
    end
    return nil, m_opts
  end

  return nil, nil
end

--- Resolve which parsers are enabled and build dispatch entries.
---@param opts table New-format options
---@return table[] Array of { spec, parser_config?, matcher_opts?, is_custom?, parser_def? } sorted by priority
local function resolve_enabled_parsers(opts)
  local enabled = {}

  -- Check each registered parser
  for _, spec in ipairs(registry.all()) do
    if is_parser_enabled(spec, opts) then
      local parser_config, matcher_opts = build_entry_config(spec, opts)
      enabled[#enabled + 1] = {
        spec = spec,
        parser_config = parser_config,
        matcher_opts = matcher_opts,
      }
    end
  end

  -- Wrap custom parsers into pseudo-specs
  local p = opts.parsers
  if p.custom and #p.custom > 0 then
    for _, parser_def in ipairs(p.custom) do
      local dispatch
      local priority
      if parser_def.prefix_bytes and parser_def.prefixes then
        dispatch = { kind = "byte+prefix", bytes = parser_def.prefix_bytes, prefixes = parser_def.prefixes }
        priority = 5
      elseif parser_def.prefix_bytes then
        dispatch = { kind = "byte", bytes = parser_def.prefix_bytes }
        priority = 5
      elseif parser_def.prefixes then
        dispatch = { kind = "prefix", prefixes = parser_def.prefixes }
        priority = 18
      else
        dispatch = { kind = "fallback" }
        priority = 30
      end

      enabled[#enabled + 1] = {
        spec = {
          name = parser_def.name,
          priority = priority,
          dispatch = dispatch,
          parse = parser_def.parse,
        },
        is_custom = true,
        parser_def = parser_def,
      }
    end
  end

  -- Sort by priority (ascending = lower number first)
  table.sort(enabled, function(a, b)
    return a.spec.priority < b.spec.priority
  end)

  return enabled
end

--- Build the 3-phase dispatcher from enabled parsers.
---@param enabled_parsers table[] From resolve_enabled_parsers
---@param hooks table|nil Hook functions
---@param opts table Full resolved options
---@return function parse_fn(line, i, bufnr, line_nr) -> len?, hex?
local function compile(enabled_parsers, hooks, opts)
  -- Phase 1 structure: byte -> [{entry, ...}] in priority order
  local byte_dispatch = {}
  -- Phase 2 structure: trie + prefix -> entry map
  local prefix_entries = {}
  local prefix_map = {}
  -- Phase 3 structure: [{entry, ...}] in priority order
  local fallback_list = {}

  for _, entry in ipairs(enabled_parsers) do
    local kind = entry.spec.dispatch.kind

    if kind == "byte" then
      for _, b in ipairs(entry.spec.dispatch.bytes) do
        byte_dispatch[b] = byte_dispatch[b] or {}
        byte_dispatch[b][#byte_dispatch[b] + 1] = entry
      end
    elseif kind == "prefix" then
      for _, pfx in ipairs(entry.spec.dispatch.prefixes) do
        -- First writer wins (lower priority number = higher priority)
        if not prefix_map[pfx] then
          prefix_entries[#prefix_entries + 1] = pfx
          prefix_map[pfx] = entry
        end
      end
    elseif kind == "fallback" then
      fallback_list[#fallback_list + 1] = entry
    elseif kind == "byte+fallback" then
      if entry.spec.dispatch.bytes then
        for _, b in ipairs(entry.spec.dispatch.bytes) do
          byte_dispatch[b] = byte_dispatch[b] or {}
          byte_dispatch[b][#byte_dispatch[b] + 1] = entry
        end
      end
      fallback_list[#fallback_list + 1] = entry
    elseif kind == "byte+prefix" then
      if entry.spec.dispatch.bytes then
        for _, b in ipairs(entry.spec.dispatch.bytes) do
          byte_dispatch[b] = byte_dispatch[b] or {}
          byte_dispatch[b][#byte_dispatch[b] + 1] = entry
        end
      end
      if entry.spec.dispatch.prefixes then
        for _, pfx in ipairs(entry.spec.dispatch.prefixes) do
          if not prefix_map[pfx] then
            prefix_entries[#prefix_entries + 1] = pfx
            prefix_map[pfx] = entry
          end
        end
      end
    end
  end

  -- Sort prefix entries by length descending for trie construction
  table.sort(prefix_entries, function(a, b)
    return #a > #b
  end)
  local trie = #prefix_entries > 0 and Trie(prefix_entries) or nil

  -- Reusable context table (mutated per call, avoids per-call allocations)
  local ctx = {
    line = "",
    col = 0,
    bufnr = 0,
    line_nr = 0,
    opts = opts,
    parser_config = nil,
    prefix = nil,
    matcher_opts = nil,
    -- Custom parser backward compat fields
    parser_opts = nil,
    state = nil,
  }

  --- Try dispatching to a parser entry.
  ---@return number|nil, string|nil
  local function try_parser(entry, prefix)
    if entry.is_custom then
      local pd = entry.parser_def
      local st = buffer_parser_state[ctx.bufnr]
        and buffer_parser_state[ctx.bufnr][pd.name]
      ctx.parser_opts = pd
      ctx.state = st or {}
    else
      ctx.parser_config = entry.parser_config
      ctx.matcher_opts = entry.matcher_opts
      ctx.prefix = prefix
    end
    return entry.spec.parse(ctx)
  end

  local function parse_fn(line, i, bufnr, line_nr)
    if
      hooks
      and hooks.disable_line_highlight
      and hooks.disable_line_highlight(line, bufnr, line_nr)
    then
      return
    end

    -- Set common context fields once per call
    ctx.line = line
    ctx.col = i
    ctx.bufnr = bufnr
    ctx.line_nr = line_nr

    -- Phase 1: byte-dispatched parsers
    local byte_parsers = byte_dispatch[line:byte(i)]
    if byte_parsers then
      for _, entry in ipairs(byte_parsers) do
        local len, rgb_hex = try_parser(entry, nil)
        if len and rgb_hex then
          return len, rgb_hex
        end
      end
    end

    -- Phase 2: prefix-dispatched parsers via trie
    if trie then
      local prefix = trie:longest_prefix(line, i)
      if prefix and prefix_map[prefix] then
        local len, rgb_hex = try_parser(prefix_map[prefix], prefix)
        if len and rgb_hex then
          return len, rgb_hex
        end
      end
    end

    -- Phase 3: fallback parsers
    for _, entry in ipairs(fallback_list) do
      local len, rgb_hex = try_parser(entry, nil)
      if len and rgb_hex then
        return len, rgb_hex
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

  local enabled = resolve_enabled_parsers(opts)
  loop_parse_fn = compile(enabled, f.hooks, opts)
  matcher_cache[matcher_key] = loop_parse_fn

  return loop_parse_fn
end

return M
