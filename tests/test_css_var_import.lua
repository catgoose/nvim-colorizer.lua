local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local css_var = require("colorizer.parser.css_var")
local config = require("colorizer.config")

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

-- @import scanning --------------------------------------------------------

T["imports"] = new_set()

T["imports"]["resolves variables from @import url() file"] = function()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  vim.fn.writefile({
    ":root {",
    "  --imported-color: #aabb00;",
    "  --imported-accent: #cc00dd;",
    "}",
  }, tmpdir .. "/vars.css")
  local bufnr = make_buf({
    '@import url("vars.css");',
    ":root {",
    "  --local-color: #112233;",
    "}",
  })
  vim.api.nvim_buf_set_name(bufnr, tmpdir .. "/main.css")
  css_var.update_variables(bufnr, 0, -1, nil, color_parser)
  local _, hex1 = css_var.parser("var(--imported-color)", 1, bufnr)
  local _, hex2 = css_var.parser("var(--imported-accent)", 1, bufnr)
  local _, hex3 = css_var.parser("var(--local-color)", 1, bufnr)
  eq("aabb00", hex1)
  eq("cc00dd", hex2)
  eq("112233", hex3)
  css_var.cleanup(bufnr)
  vim.fn.delete(tmpdir, "rf")
end

T["imports"]["local definitions override imported"] = function()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  vim.fn.writefile({ "  --color: #111111;" }, tmpdir .. "/vars.css")
  local bufnr = make_buf({
    '@import url("vars.css");',
    "  --color: #222222;",
  })
  vim.api.nvim_buf_set_name(bufnr, tmpdir .. "/main.css")
  css_var.update_variables(bufnr, 0, -1, nil, color_parser)
  local _, hex = css_var.parser("var(--color)", 1, bufnr)
  eq("222222", hex)
  css_var.cleanup(bufnr)
  vim.fn.delete(tmpdir, "rf")
end

T["imports"]["handles @import with single quotes"] = function()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  vim.fn.writefile({ "  --sq: #aaaaaa;" }, tmpdir .. "/sq.css")
  local bufnr = make_buf({ "@import url('sq.css');" })
  vim.api.nvim_buf_set_name(bufnr, tmpdir .. "/main.css")
  css_var.update_variables(bufnr, 0, -1, nil, color_parser)
  local _, hex = css_var.parser("var(--sq)", 1, bufnr)
  eq("aaaaaa", hex)
  css_var.cleanup(bufnr)
  vim.fn.delete(tmpdir, "rf")
end

T["imports"]["handles @import without url()"] = function()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  vim.fn.writefile({ "  --bare: #bbbbbb;" }, tmpdir .. "/bare.css")
  local bufnr = make_buf({ '@import "bare.css";' })
  vim.api.nvim_buf_set_name(bufnr, tmpdir .. "/main.css")
  css_var.update_variables(bufnr, 0, -1, nil, color_parser)
  local _, hex = css_var.parser("var(--bare)", 1, bufnr)
  eq("bbbbbb", hex)
  css_var.cleanup(bufnr)
  vim.fn.delete(tmpdir, "rf")
end

T["imports"]["missing import file is silently skipped"] = function()
  local bufnr = make_buf({
    '@import url("nonexistent.css");',
    "  --local: #ffffff;",
  })
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  vim.api.nvim_buf_set_name(bufnr, tmpdir .. "/main.css")
  css_var.update_variables(bufnr, 0, -1, nil, color_parser)
  local _, hex = css_var.parser("var(--local)", 1, bufnr)
  eq("ffffff", hex)
  css_var.cleanup(bufnr)
  vim.fn.delete(tmpdir, "rf")
end

T["imports"]["resolves aliased vars across import boundary"] = function()
  local tmpdir = vim.fn.tempname()
  vim.fn.mkdir(tmpdir, "p")
  vim.fn.writefile({ "  --base: #abcdef;" }, tmpdir .. "/vars.css")
  local bufnr = make_buf({
    '@import url("vars.css");',
    "  --alias: var(--base);",
  })
  vim.api.nvim_buf_set_name(bufnr, tmpdir .. "/main.css")
  css_var.update_variables(bufnr, 0, -1, nil, color_parser)
  local _, hex = css_var.parser("var(--alias)", 1, bufnr)
  eq("abcdef", hex)
  css_var.cleanup(bufnr)
  vim.fn.delete(tmpdir, "rf")
end

T["imports"]["unnamed buffer skips import resolution"] = function()
  local bufnr = make_buf({
    '@import url("vars.css");',
    "  --local: #aaaaaa;",
  })
  css_var.update_variables(bufnr, 0, -1, nil, color_parser)
  local _, hex = css_var.parser("var(--local)", 1, bufnr)
  eq("aaaaaa", hex)
  css_var.cleanup(bufnr)
end

-- config ------------------------------------------------------------------

T["config"] = new_set()

T["config"]["css preset enables css_var"] = function()
  local opts = config.resolve_options({
    parsers = { css = true },
  })
  eq(true, opts.parsers.css_var.enable)
end

return T
