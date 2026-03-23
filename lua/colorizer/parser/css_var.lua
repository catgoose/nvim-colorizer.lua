---@mod colorizer.parser.css_var CSS Custom Properties Parser
---@brief [[
---Parses CSS custom property definitions (--name: <color>) and resolves
---var(--name) references. Stateful: scans the buffer for definitions before
---parsing, similar to the Sass variable parser.
---@brief ]]
local M = {}

local state = {}

--- Cleanup per-buffer state
---@param bufnr number
function M.cleanup(bufnr)
  state[bufnr] = nil
end

local VAR_REF_PATTERN = "^var%(%s*%-%-([%w_-]+)%s*[,)]"

--- Parse a var(--name) reference and look up its color
---@param line string
---@param i number 1-indexed column
---@param bufnr number
---@return number|nil length consumed
---@return string|nil rgb_hex
function M.parser(line, i, bufnr)
  if not state[bufnr] then
    return
  end
  local sub = line:sub(i)
  local variable_name = sub:match(VAR_REF_PATTERN)
  if not variable_name then
    return
  end
  local rgb_hex = state[bufnr].definitions[variable_name]
  if not rgb_hex then
    return
  end
  -- Find the closing paren to get consumed length, handling nested parens in fallback
  local depth = 0
  for j = 1, #sub do
    local c = sub:byte(j)
    if c == 0x28 then -- (
      depth = depth + 1
    elseif c == 0x29 then -- )
      depth = depth - 1
      if depth == 0 then
        return j, rgb_hex
      end
    end
  end
end

local DEF_PATTERN = "^%-%-([%w_-]+)%s*:%s*()(.+)"

--- Scan lines for CSS custom property definitions into defs/recursive tables.
---@param lines table Lines to scan
---@param defs table Direct color definitions (name -> rgb_hex), mutated
---@param recursive table Recursive references (name -> ref_name), mutated
---@param color_parser function|nil
local function scan_lines_for_defs(lines, defs, recursive, color_parser)
  for _, line in ipairs(lines) do
    local s = line:find("%-%-")
    if s then
      local name, _, value = line:match(DEF_PATTERN, s)
      if name and value then
        value = value:match("^(.-)%s*;?%s*$")
        value = value and value:match("^(.-)%s*!important%s*$") or value
        if value and #value > 0 then
          local ref_name = value:match("^var%(%s*%-%-([%w_-]+)")
          if ref_name then
            recursive[name] = ref_name
          elseif color_parser then
            local length, rgb_hex = color_parser(value, 1)
            if length and rgb_hex then
              defs[name] = rgb_hex
            end
          end
        end
      end
    end
  end
end

--- Extract @import file paths from CSS lines.
--- Supports @import url("..."), @import url('...'), @import "...", @import '...'.
---@param lines table Lines to scan
---@return string[] import_paths
local function extract_imports(lines)
  local paths = {}
  for _, line in ipairs(lines) do
    -- @import url("path") or @import url('path')
    local p = line:match('@import%s+url%(%s*"([^"]+)"')
      or line:match("@import%s+url%(%s*'([^']+)'")
      -- @import "path" or @import 'path'
      or line:match('@import%s+"([^"]+)"')
      or line:match("@import%s+'([^']+)'")
    if p then
      paths[#paths + 1] = p
    end
  end
  return paths
end

--- Read an imported CSS file relative to the buffer's directory.
---@param bufnr number
---@param import_path string
---@return string[]|nil lines
local function read_import(bufnr, import_path)
  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  if buf_name == "" then
    return nil
  end
  local buf_dir = vim.fn.fnamemodify(buf_name, ":h")
  local full_path = buf_dir .. "/" .. import_path
  -- Normalize and check existence
  full_path = vim.fn.resolve(full_path)
  if vim.fn.filereadable(full_path) ~= 1 then
    return nil
  end
  return vim.fn.readfile(full_path)
end

--- Scan buffer lines for CSS custom property definitions
---@param bufnr number
---@param line_start number 0-indexed
---@param line_end number -1 for end of buffer
---@param lines table|nil
---@param color_parser function Parser function to extract colors from values
function M.update_variables(bufnr, line_start, line_end, lines, color_parser)
  lines = lines or vim.api.nvim_buf_get_lines(bufnr, line_start, line_end, false)

  if not state[bufnr] then
    state[bufnr] = { definitions = {} }
  end

  local defs = {}
  local recursive = {}

  -- Scan imported files first (lower priority — buffer definitions override)
  local imports = extract_imports(lines)
  for _, import_path in ipairs(imports) do
    local import_lines = read_import(bufnr, import_path)
    if import_lines then
      scan_lines_for_defs(import_lines, defs, recursive, color_parser)
    end
  end

  -- Scan buffer lines (higher priority — overwrites imported definitions)
  scan_lines_for_defs(lines, defs, recursive, color_parser)

  -- Resolve recursive references (var(--other))
  local function resolve(name, seen)
    if defs[name] then
      return defs[name]
    end
    local ref = recursive[name]
    if not ref then
      return nil
    end
    seen = seen or {}
    if seen[name] then
      return nil
    end
    seen[name] = true
    return resolve(ref, seen)
  end

  for name, _ in pairs(recursive) do
    local resolved = resolve(name)
    if resolved then
      defs[name] = resolved
    end
  end

  state[bufnr].definitions = defs
end

M.spec = {
  name = "css_var",
  priority = 19,
  dispatch = { kind = "prefix", prefixes = { "var(" } },
  config_defaults = {
    enable = false,
    parsers = { css = true },
  },
  stateful = true,
  parse = function(ctx)
    return M.parser(ctx.line, ctx.col, ctx.bufnr)
  end,
}

require("colorizer.parser.registry").register(M.spec)

return M
