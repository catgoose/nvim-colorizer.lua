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

T["add_highlight"]["sets extmarks in underline mode"] = function()
  local buf = make_buf({ "#FF8800 text" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_ul")
  local opts = all_opts({ mode = "underline" })
  local data = buffer.parse_lines(buf, { "#FF8800 text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(true, #marks > 0)
  -- Underline highlight name should contain "mu" (underline mode)
  eq(true, marks[1][4].hl_group:find("mu") ~= nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["add_highlight"]["underline mode sets sp and underline attribute"] = function()
  local buf = make_buf({ "#FF8800 text" })
  local ns = vim.api.nvim_create_namespace("test_add_hl_ul_attrs")
  local opts = all_opts({ mode = "underline" })
  local data = buffer.parse_lines(buf, { "#FF8800 text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  local hl_name = marks[1][4].hl_group
  local hl_def = vim.api.nvim_get_hl(0, { name = hl_name })
  eq(true, hl_def.underline == true)
  eq(true, hl_def.sp ~= nil)
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

T["priority"]["default priority matches diagnostics"] = function()
  local expected = (vim.hl and vim.hl.priorities and vim.hl.priorities.diagnostics) or 150
  local buf = make_buf({ "#FF0000" })
  local ns = vim.api.nvim_create_namespace("test_priority_default")
  local opts = all_opts({ mode = "background" })
  local data = buffer.parse_lines(buf, { "#FF0000" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(expected, marks[1][4].priority)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["priority"]["tailwind_lsp priority matches user"] = function()
  local expected = (vim.hl and vim.hl.priorities and vim.hl.priorities.user) or 200
  local buf = make_buf({ "#FF0000" })
  local ns = vim.api.nvim_create_namespace("test_priority_lsp")
  local opts = all_opts({ mode = "background" })
  local data = buffer.parse_lines(buf, { "#FF0000" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts, { tailwind_lsp = true })
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(expected, marks[1][4].priority)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- combined display modes ------------------------------------------------------

T["combined modes"] = new_set()

T["combined modes"]["table mode works like string for single mode"] = function()
  local buf = make_buf({ "#FF0000 text" })
  local ns = vim.api.nvim_create_namespace("test_combined_single")
  local opts = config.resolve_options({ parsers = { css = true }, display = { mode = { "background" } } })
  local data = buffer.parse_lines(buf, { "#FF0000 text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(true, #marks > 0)
  eq(true, marks[1][4].hl_group:find("mb") ~= nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["combined modes"]["background + underline produces one extmark with both attrs"] = function()
  local buf = make_buf({ "#FF0000 text" })
  local ns = vim.api.nvim_create_namespace("test_combined_bg_ul")
  local opts = config.resolve_options({
    parsers = { css = true },
    display = { mode = { "background", "underline" } },
  })
  local data = buffer.parse_lines(buf, { "#FF0000 text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(1, #marks) -- single extmark, not two
  local hl_name = marks[1][4].hl_group
  -- Should contain both mode codes
  eq(true, hl_name:find("mb") ~= nil)
  eq(true, hl_name:find("mu") ~= nil)
  -- Verify actual highlight attributes
  local hl = vim.api.nvim_get_hl(0, { name = hl_name })
  eq(true, hl.bg ~= nil) -- background set
  eq(true, hl.sp ~= nil) -- underline sp set
  eq(true, hl.underline == true)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["combined modes"]["foreground + underline produces one extmark"] = function()
  local buf = make_buf({ "#00FF00 text" })
  local ns = vim.api.nvim_create_namespace("test_combined_fg_ul")
  local opts = config.resolve_options({
    parsers = { css = true },
    display = { mode = { "foreground", "underline" } },
  })
  local data = buffer.parse_lines(buf, { "#00FF00 text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(1, #marks)
  local hl = vim.api.nvim_get_hl(0, { name = marks[1][4].hl_group })
  eq(true, hl.fg ~= nil) -- foreground color set
  eq(true, hl.sp ~= nil) -- underline sp set
  eq(true, hl.underline == true)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["combined modes"]["background + virtualtext produces two extmarks"] = function()
  local buf = make_buf({ "#FF0000 text" })
  local ns = vim.api.nvim_create_namespace("test_combined_bg_vt")
  local opts = config.resolve_options({
    parsers = { css = true },
    display = { mode = { "background", "virtualtext" }, virtualtext = { position = "eol" } },
  })
  local data = buffer.parse_lines(buf, { "#FF0000 text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(2, #marks) -- one hl_group extmark + one virtualtext extmark
  -- One should have hl_group (background), the other virt_text
  local has_hl = false
  local has_vt = false
  for _, m in ipairs(marks) do
    if m[4].hl_group then
      has_hl = true
    end
    if m[4].virt_text then
      has_vt = true
    end
  end
  eq(true, has_hl)
  eq(true, has_vt)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["combined modes"]["virtualtext-only table works"] = function()
  local buf = make_buf({ "#FF0000 text" })
  local ns = vim.api.nvim_create_namespace("test_combined_vt_only")
  local opts = config.resolve_options({
    parsers = { css = true },
    display = { mode = { "virtualtext" } },
  })
  local data = buffer.parse_lines(buf, { "#FF0000 text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(1, #marks) -- only virtualtext
  eq(true, marks[1][4].virt_text ~= nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["combined modes"]["all four modes produces two extmarks"] = function()
  local buf = make_buf({ "#0000FF text" })
  local ns = vim.api.nvim_create_namespace("test_combined_all")
  local opts = config.resolve_options({
    parsers = { css = true },
    display = { mode = { "background", "foreground", "underline", "virtualtext" } },
  })
  local data = buffer.parse_lines(buf, { "#0000FF text" }, 0, opts)
  buffer.add_highlight(buf, ns, 0, 1, data, opts)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  eq(2, #marks) -- one combined non-vt + one vt
  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
