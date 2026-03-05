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
  -- First pass: collect direct color definitions
  local recursive = {}
  for _, line in ipairs(lines) do
    -- Find -- at any position in the line (CSS custom properties can be indented)
    local s = line:find("%-%-")
    if s then
      local name, value_pos, value = line:match(DEF_PATTERN, s)
      if name and value then
        -- Strip trailing semicolons, whitespace, !important
        value = value:match("^(.-)%s*;?%s*$")
        value = value and value:match("^(.-)%s*!important%s*$") or value
        if value and #value > 0 then
          -- Check if value references another variable
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
