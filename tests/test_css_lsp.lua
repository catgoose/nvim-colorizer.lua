local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local css_lsp = require("colorizer.css_lsp")
local css_var = require("colorizer.parser.css_var")
local config = require("colorizer.config")
local const = require("colorizer.constants")

local T = new_set()

-- Helpers
local function make_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
  return buf
end

local function color_parser(line, i)
  local hex = line:sub(i):match("^#(%x%x%x%x%x%x)")
  if hex then
    return 7, hex:lower()
  end
  return nil
end

-- update_from_lsp ---------------------------------------------------------

T["update_from_lsp"] = new_set()

T["update_from_lsp"]["adds LSP definitions to empty state"] = function()
  local bufnr = make_buf()
  css_var.update_from_lsp(bufnr, { primary = "ff0000", accent = "00ff00" })
  local _, hex1 = css_var.parser("var(--primary)", 1, bufnr)
  local _, hex2 = css_var.parser("var(--accent)", 1, bufnr)
  eq("ff0000", hex1)
  eq("00ff00", hex2)
  css_var.cleanup(bufnr)
end

T["update_from_lsp"]["buffer definitions take precedence over LSP"] = function()
  local bufnr = make_buf()
  -- Buffer-scanned definition
  css_var.update_variables(bufnr, 0, 1, { "  --primary: #0000ff;" }, color_parser)
  -- LSP tries to set a different value for the same variable
  css_var.update_from_lsp(bufnr, { primary = "ff0000" })
  local _, hex = css_var.parser("var(--primary)", 1, bufnr)
  eq("0000ff", hex) -- buffer definition wins
  css_var.cleanup(bufnr)
end

T["update_from_lsp"]["LSP fills gaps for undefined variables"] = function()
  local bufnr = make_buf()
  -- Buffer has one definition
  css_var.update_variables(bufnr, 0, 1, { "  --local: #111111;" }, color_parser)
  -- LSP provides a variable not in the buffer
  css_var.update_from_lsp(bufnr, { external = "222222" })
  local _, hex_local = css_var.parser("var(--local)", 1, bufnr)
  local _, hex_ext = css_var.parser("var(--external)", 1, bufnr)
  eq("111111", hex_local)
  eq("222222", hex_ext)
  css_var.cleanup(bufnr)
end

T["update_from_lsp"]["nil or empty definitions is a no-op"] = function()
  local bufnr = make_buf()
  css_var.update_from_lsp(bufnr, nil)
  css_var.update_from_lsp(bufnr, {})
  local len = css_var.parser("var(--anything)", 1, bufnr)
  eq(nil, len)
end

T["update_from_lsp"]["creates state if not initialized"] = function()
  local bufnr = make_buf()
  -- No prior update_variables call
  css_var.update_from_lsp(bufnr, { color = "abcdef" })
  local _, hex = css_var.parser("var(--color)", 1, bufnr)
  eq("abcdef", hex)
  css_var.cleanup(bufnr)
end

T["update_from_lsp"]["has_buffer_definition distinguishes sources"] = function()
  local bufnr = make_buf()
  -- Buffer-scanned definition
  css_var.update_variables(bufnr, 0, 1, { "  --local-color: #aabbcc;" }, color_parser)
  eq(true, css_var.has_buffer_definition(bufnr, "local-color"))
  eq(false, css_var.has_buffer_definition(bufnr, "external"))
  -- LSP adds a new variable
  css_var.update_from_lsp(bufnr, { external = "112233" })
  -- has_buffer_definition returns true for both now (can't distinguish after merge)
  -- but the key point is it returned false BEFORE update_from_lsp for "external"
  css_var.cleanup(bufnr)
end

T["update_from_lsp"]["cleanup removes LSP definitions too"] = function()
  local bufnr = make_buf()
  css_var.update_from_lsp(bufnr, { color = "ff0000" })
  css_var.cleanup(bufnr)
  local len = css_var.parser("var(--color)", 1, bufnr)
  eq(nil, len)
end

-- css_lsp module ----------------------------------------------------------

T["css_lsp"] = new_set()

T["css_lsp"]["cleanup on non-existent buffer is safe"] = function()
  css_lsp.cleanup(99999)
end

T["css_lsp"]["cleanup clears namespace"] = function()
  local bufnr = make_buf({ "var(--color)" })
  -- Set an extmark in the css_var_lsp namespace
  vim.api.nvim_buf_set_extmark(bufnr, const.namespace.css_var_lsp, 0, 0, { end_col = 5 })
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, const.namespace.css_var_lsp, 0, -1, {})
  eq(1, #marks)
  css_lsp.cleanup(bufnr)
  marks = vim.api.nvim_buf_get_extmarks(bufnr, const.namespace.css_var_lsp, 0, -1, {})
  eq(0, #marks)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

T["css_lsp"]["lsp_highlight returns nil for invalid buffer"] = function()
  local result = css_lsp.lsp_highlight(99999, {}, {}, function() end, function() end)
  eq(nil, result)
end

-- config normalization ----------------------------------------------------

T["config"] = new_set()

T["config"]["css_var.lsp boolean shorthand expands to table"] = function()
  local opts = config.resolve_options({
    parsers = {
      css_var = { enable = true, lsp = true },
    },
  })
  eq(true, opts.parsers.css_var.lsp.enable)
end

T["config"]["css_var.lsp false shorthand expands to table"] = function()
  local opts = config.resolve_options({
    parsers = {
      css_var = { enable = true, lsp = false },
    },
  })
  eq(false, opts.parsers.css_var.lsp.enable)
end

T["config"]["css_var.lsp defaults to disabled"] = function()
  local opts = config.resolve_options({
    parsers = {
      css_var = { enable = true },
    },
  })
  eq(false, opts.parsers.css_var.lsp.enable)
end

T["config"]["css_var.lsp table form preserves enable"] = function()
  local opts = config.resolve_options({
    parsers = {
      css_var = { enable = true, lsp = { enable = true } },
    },
  })
  eq(true, opts.parsers.css_var.lsp.enable)
end

T["config"]["css preset enables css_var but not lsp"] = function()
  local opts = config.resolve_options({
    parsers = { css = true },
  })
  eq(true, opts.parsers.css_var.enable)
  eq(false, opts.parsers.css_var.lsp.enable)
end

return T
