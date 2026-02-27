local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local buffer = require("colorizer.buffer")
local config = require("colorizer.config")
local const = require("colorizer.constants")
local matcher = require("colorizer.matcher")
local names = require("colorizer.parser.names")

local T = new_set({
  hooks = {
    pre_case = function()
      names.reset_cache()
      buffer.reset_cache()
      matcher.reset_cache()
      config.get_setup_options(nil)
    end,
  },
})

-- Helper: create a scratch buffer with given lines
local function make_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

-- Helper: standard opts
local function all_opts(overrides)
  local base = {
    css = true,
    AARRGGBB = true,
    xterm = true,
    tailwind = false,
    names_opts = {
      lowercase = true,
      camelcase = false,
      uppercase = false,
      strip_digits = false,
    },
  }
  if overrides then
    base = vim.tbl_deep_extend("force", base, overrides)
  end
  return config.apply_alias_options(base)
end

-- add_highlight: background mode ----------------------------------------------

T["add_highlight"] = new_set()

T["add_highlight"]["sets extmarks in background mode"] = function()
  local buf = make_buf({ "#FF0000 text" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_bg")
  local opts = all_opts({ mode = "background" })
  local data = buffer.parse_lines(buf, { "#FF0000 text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(true, #marks > 0)
  -- Check extmark position: line 0, start col 0
  eq(0, marks[1][2]) -- row
  eq(0, marks[1][3]) -- col
  -- Check it has a highlight group
  eq(true, marks[1][4].hl_group ~= nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["add_highlight"]["sets extmarks in foreground mode"] = function()
  local buf = make_buf({ "#00FF00 text" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_fg")
  local opts = all_opts({ mode = "foreground" })
  local data = buffer.parse_lines(buf, { "#00FF00 text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(true, #marks > 0)
  -- Foreground highlight name should contain "mf" (foreground mode)
  eq(true, marks[1][4].hl_group:find("mf") ~= nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["add_highlight"]["sets virtualtext extmarks"] = function()
  local buf = make_buf({ "#0000FF text" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_vt")
  local opts = all_opts({ mode = "virtualtext" })
  local data = buffer.parse_lines(buf, { "#0000FF text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(true, #marks > 0)
  -- Virtualtext should have virt_text field
  eq(true, marks[1][4].virt_text ~= nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["add_highlight"]["virtualtext_inline after"] = function()
  local buf = make_buf({ "#FF00FF text" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_vt_inline")
  local opts = all_opts({ mode = "virtualtext", virtualtext_inline = "after" })
  local data = buffer.parse_lines(buf, { "#FF00FF text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(true, #marks > 0)
  eq("inline", marks[1][4].virt_text_pos)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["add_highlight"]["virtualtext_inline before"] = function()
  local buf = make_buf({ "#AABBCC text" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_vt_before")
  local opts = all_opts({ mode = "virtualtext", virtualtext_inline = "before" })
  local data = buffer.parse_lines(buf, { "#AABBCC text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(true, #marks > 0)
  eq("inline", marks[1][4].virt_text_pos)
  -- "before" should start at column 0 (the start of the color)
  eq(0, marks[1][3])
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["add_highlight"]["clears previous extmarks in namespace"] = function()
  local buf = make_buf({ "#FF0000 text" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_clear")
  local opts = all_opts({ mode = "background" })
  local data = buffer.parse_lines(buf, { "#FF0000 text" }, 0, opts)
  -- Add highlights twice
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  -- Should only have marks from the second call (first were cleared)
  eq(1, #marks)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["add_highlight"]["multiple colors on one line"] = function()
  local buf = make_buf({ "#FF0000 #00FF00 #0000FF" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_multi")
  local opts = all_opts({ mode = "background" })
  local data = buffer.parse_lines(buf, { "#FF0000 #00FF00 #0000FF" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  eq(3, #marks)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["add_highlight"]["no data produces no extmarks"] = function()
  local buf = make_buf({ "no colors here" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_empty")
  local opts = all_opts({ mode = "background" })
  buffer.add_highlight(buf, ns, 0, 1, {}, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  eq(0, #marks)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- highlight (full pipeline) ---------------------------------------------------

T["highlight"] = new_set()

T["highlight"]["returns detach table with ns_id and functions"] = function()
  local buf = make_buf({ "#FF0000" })
  local opts = all_opts()
  local detach = buffer.highlight(buf, const.namespace.default, 0, 1, opts, {})
  eq("table", type(detach))
  eq("table", type(detach.ns_id))
  eq("table", type(detach.functions))
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["highlight"]["creates extmarks in default namespace"] = function()
  local buf = make_buf({ "#FF0000" })
  local opts = all_opts()
  buffer.highlight(buf, const.namespace.default, 0, 1, opts, {})
  local marks = vim.api.nvim_buf_get_extmarks(buf, const.namespace.default, 0, -1, {})
  eq(true, #marks > 0)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["highlight"]["empty buffer creates no extmarks"] = function()
  local buf = make_buf({ "plain text" })
  local opts = all_opts()
  buffer.highlight(buf, const.namespace.default, 0, 1, opts, {})
  local marks = vim.api.nvim_buf_get_extmarks(buf, const.namespace.default, 0, -1, {})
  eq(0, #marks)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["highlight"]["sass enabled adds cleanup to detach functions"] = function()
  local buf = make_buf({ "$color: #ff0000;" })
  vim.api.nvim_buf_set_name(buf, "/tmp/test_hl_sass_" .. buf .. ".scss")
  local opts = all_opts({ sass = { enable = true, parsers = { css = true } } })
  local detach = buffer.highlight(buf, const.namespace.default, 0, 1, opts, {})
  -- detach.functions should contain sass.cleanup
  eq(true, #detach.functions > 0)
  -- Clean up
  require("colorizer.sass").cleanup(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- Priority --------------------------------------------------------------------

T["priority"] = new_set()

T["priority"]["default priority is diagnostics"] = function()
  local buf = make_buf({ "#FF0000" })
  local ns = vim.api.nvim_create_namespace("test_priority_default")
  local opts = all_opts({ mode = "background" })
  local data = buffer.parse_lines(buf, { "#FF0000" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(vim.hl.priorities.diagnostics, marks[1][4].priority)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["priority"]["tailwind_lsp priority is user"] = function()
  local buf = make_buf({ "#FF0000" })
  local ns = vim.api.nvim_create_namespace("test_priority_lsp")
  local opts = all_opts({ mode = "background" })
  local data = buffer.parse_lines(buf, { "#FF0000" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts, { tailwind_lsp = true })
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(vim.hl.priorities.user, marks[1][4].priority)
  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
