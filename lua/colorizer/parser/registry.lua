---@mod colorizer.parser.registry Parser Registry
---@brief [[
---Central registry for all color parsers. Each parser registers a spec
---describing its config defaults, dispatch mechanism, and parse function.
---@brief ]]
local M = {}

---@class colorizer.ParserSpec
---@field name string         Config key under opts.parsers
---@field priority number     Dispatch order (lower = first). 10=byte, 20=prefix, 25=fallback
---@field dispatch { kind: string, bytes?: number[], prefixes?: string[] }
---@field config_defaults table   Default config for opts.parsers.<name>
---@field parse fun(ctx: colorizer.ParseContext): number?, string?
---@field init? fun(ctx: colorizer.ParseContext)       Per-buffer init (stateful parsers)
---@field cleanup? fun(ctx: colorizer.ParseContext)    Per-buffer cleanup
---@field reset_cache? fun()   Module-level cache reset
---@field stateful? boolean    Per-buffer state managed by registry

---@class colorizer.ParseContext
---@field line string
---@field col number          1-indexed
---@field bufnr number
---@field line_nr number      0-indexed
---@field opts table          Full resolved buffer options
---@field parser_config table This parser's subtable from opts.parsers.<name>
---@field prefix? string      Matched trie prefix (prefix-dispatched only)
---@field matcher_opts? table Pre-built config (names parser compatibility)

local specs = {}       -- name -> spec
local sorted = nil     -- cached sorted-by-priority list, invalidated on register

--- Register a parser spec.
---@param spec colorizer.ParserSpec
function M.register(spec)
  assert(spec.name, "ParserSpec must have a name")
  assert(spec.parse, "ParserSpec must have a parse function")
  assert(spec.dispatch, "ParserSpec must have a dispatch table")
  assert(spec.priority, "ParserSpec must have a priority")
  specs[spec.name] = spec
  sorted = nil  -- invalidate cache
end

--- Look up a parser spec by name.
---@param name string
---@return colorizer.ParserSpec|nil
function M.get(name)
  return specs[name]
end

--- Return all registered specs sorted by priority (ascending).
---@return colorizer.ParserSpec[]
function M.all()
  if not sorted then
    sorted = {}
    for _, spec in pairs(specs) do
      sorted[#sorted + 1] = spec
    end
    table.sort(sorted, function(a, b)
      return a.priority < b.priority
    end)
  end
  return { unpack(sorted) }
end

--- Return a table of { name = config_defaults } for all registered parsers.
---@return table<string, table>
function M.config_defaults()
  local defaults = {}
  for name, spec in pairs(specs) do
    if spec.config_defaults then
      defaults[name] = vim.deepcopy(spec.config_defaults)
    end
  end
  return defaults
end

--- Call reset_cache on all parsers that define it.
function M.reset_all_caches()
  for _, spec in pairs(specs) do
    if spec.reset_cache then
      spec.reset_cache()
    end
  end
end

--- Clear all registered specs (for testing).
function M._clear()
  specs = {}
  sorted = nil
end

return M
