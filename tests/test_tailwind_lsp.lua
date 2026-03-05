local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local buffer = require("colorizer.buffer")
local config = require("colorizer.config")
local const = require("colorizer.constants")
local matcher = require("colorizer.matcher")
local names = require("colorizer.parser.names")
local tailwind = require("colorizer.tailwind")

local tw_ns = const.namespace.tailwind_lsp
local default_ns = const.namespace.default

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

-- Helpers ---------------------------------------------------------------------

local function make_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

--- Build resolved opts with tailwind.enable + tailwind.lsp both on
local function tw_opts(mode, overrides)
  local base = {
    css = true,
    tailwind = "both",
    mode = mode or "virtualtext",
  }
  if overrides then
    base = vim.tbl_deep_extend("force", base, overrides)
  end
  return config.apply_alias_options(base)
end

--- Build fake LSP-style data (same shape as tailwind.lua highlight() produces)
--- Each entry: { line = 0, col_start = 0, col_end = 7, hex = "ff0000" }
local function make_lsp_data(entries)
  local data = {}
  for _, e in ipairs(entries) do
    data[e.line] = data[e.line] or {}
    table.insert(data[e.line], { rgb_hex = e.hex, range = { e.col_start, e.col_end } })
  end
  return data
end

local function get_marks(buf, ns)
  return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
end

-- add_highlight with tailwind_lsp flag ----------------------------------------

T["tw_lsp add_highlight"] = new_set()

T["tw_lsp add_highlight"]["background: multiple colors per line all get extmarks"] = function()
  local buf = make_buf({ "bg-red-500 bg-blue-500 bg-green-500" })
  local opts = tw_opts("background")
  local data = make_lsp_data({
    { line = 0, col_start = 0, col_end = 10, hex = "ef4444" },
    { line = 0, col_start = 11, col_end = 22, hex = "3b82f6" },
    { line = 0, col_start = 23, col_end = 35, hex = "22c55e" },
  })
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts, { tailwind_lsp = true })
  local marks = get_marks(buf, tw_ns)
  eq(3, #marks)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["tw_lsp add_highlight"]["virtualtext: multiple colors per line all get extmarks"] = function()
  local buf = make_buf({ "bg-red-500 bg-blue-500 bg-green-500" })
  local opts = tw_opts("virtualtext")
  local data = make_lsp_data({
    { line = 0, col_start = 0, col_end = 10, hex = "ef4444" },
    { line = 0, col_start = 11, col_end = 22, hex = "3b82f6" },
    { line = 0, col_start = 23, col_end = 35, hex = "22c55e" },
  })
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts, { tailwind_lsp = true })
  local marks = get_marks(buf, tw_ns)
  eq(3, #marks)
  -- Each should have virtualtext
  for _, m in ipairs(marks) do
    eq(true, m[4].virt_text ~= nil)
  end
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["tw_lsp add_highlight"]["foreground: multiple colors per line all get extmarks"] = function()
  local buf = make_buf({ "text-red-500 text-blue-500" })
  local opts = tw_opts("foreground")
  local data = make_lsp_data({
    { line = 0, col_start = 0, col_end = 12, hex = "ef4444" },
    { line = 0, col_start = 13, col_end = 26, hex = "3b82f6" },
  })
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts, { tailwind_lsp = true })
  local marks = get_marks(buf, tw_ns)
  eq(2, #marks)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["tw_lsp add_highlight"]["clears default namespace per line when tw_both"] = function()
  local buf = make_buf({ "bg-red-500 bg-blue-500" })
  local opts = tw_opts("background")
  -- Simulate parser-based extmarks in the default namespace
  vim.api.nvim_buf_set_extmark(buf, default_ns, 0, 0, { end_col = 10, hl_group = "Normal" })
  vim.api.nvim_buf_set_extmark(buf, default_ns, 0, 11, { end_col = 22, hl_group = "Normal" })
  eq(2, #get_marks(buf, default_ns))

  -- Apply LSP highlights — should clear default ns on that line
  local data = make_lsp_data({
    { line = 0, col_start = 0, col_end = 10, hex = "ef4444" },
    { line = 0, col_start = 11, col_end = 22, hex = "3b82f6" },
  })
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts, { tailwind_lsp = true })
  eq(0, #get_marks(buf, default_ns))
  eq(2, #get_marks(buf, tw_ns))
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["tw_lsp add_highlight"]["does not clear default ns when tailwind_lsp flag is false"] = function()
  local buf = make_buf({ "#FF0000" })
  local opts = tw_opts("background")
  -- Place a mark in default ns
  vim.api.nvim_buf_set_extmark(buf, default_ns, 0, 0, { end_col = 7, hl_group = "Normal" })
  eq(1, #get_marks(buf, default_ns))

  local data = make_lsp_data({ { line = 0, col_start = 0, col_end = 7, hex = "ff0000" } })
  -- No tailwind_lsp flag
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts)
  eq(1, #get_marks(buf, default_ns))
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["tw_lsp add_highlight"]["multiline data highlights all lines"] = function()
  local buf = make_buf({ "bg-red-500", "bg-blue-500", "bg-green-500" })
  local opts = tw_opts("virtualtext")
  local data = make_lsp_data({
    { line = 0, col_start = 0, col_end = 10, hex = "ef4444" },
    { line = 1, col_start = 0, col_end = 11, hex = "3b82f6" },
    { line = 2, col_start = 0, col_end = 12, hex = "22c55e" },
  })
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts, { tailwind_lsp = true })
  local marks = get_marks(buf, tw_ns)
  eq(3, #marks)
  -- Each on a different line
  eq(0, marks[1][2])
  eq(1, marks[2][2])
  eq(2, marks[3][2])
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- Namespace clearing (simulates the scroll-duplicate fix) ---------------------

T["tw_lsp namespace clearing"] = new_set()

T["tw_lsp namespace clearing"]["full clear before reapply prevents duplicates"] = function()
  local buf = make_buf({ "bg-red-500", "bg-blue-500" })
  local opts = tw_opts("virtualtext")
  local data = make_lsp_data({
    { line = 0, col_start = 0, col_end = 10, hex = "ef4444" },
    { line = 1, col_start = 0, col_end = 11, hex = "3b82f6" },
  })

  -- First apply (simulates initial LSP response)
  vim.api.nvim_buf_clear_namespace(buf, tw_ns, 0, -1)
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts, { tailwind_lsp = true })
  eq(2, #get_marks(buf, tw_ns))

  -- Second apply with full clear (simulates scroll reusing cached data)
  vim.api.nvim_buf_clear_namespace(buf, tw_ns, 0, -1)
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts, { tailwind_lsp = true })
  eq(2, #get_marks(buf, tw_ns))
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["tw_lsp namespace clearing"]["partial clear causes duplicates (regression guard)"] = function()
  local buf = make_buf({ "bg-red-500", "bg-blue-500", "bg-green-500" })
  local opts = tw_opts("virtualtext")
  local data = make_lsp_data({
    { line = 0, col_start = 0, col_end = 10, hex = "ef4444" },
    { line = 1, col_start = 0, col_end = 11, hex = "3b82f6" },
    { line = 2, col_start = 0, col_end = 12, hex = "22c55e" },
  })

  -- First apply — 3 marks
  vim.api.nvim_buf_clear_namespace(buf, tw_ns, 0, -1)
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts, { tailwind_lsp = true })
  eq(3, #get_marks(buf, tw_ns))

  -- Partial clear (only line 1) then reapply all — would cause dupes without full clear
  vim.api.nvim_buf_clear_namespace(buf, tw_ns, 1, 2)
  buffer.add_highlight(buf, tw_ns, 0, -1, data, opts, { tailwind_lsp = true })
  -- Without the full-clear fix this would be >3; with the tw_both per-line clear it's 3
  eq(3, #get_marks(buf, tw_ns))
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- lsp_highlight (tailwind.lua) ------------------------------------------------

T["lsp_highlight"] = new_set()

T["lsp_highlight"]["creates autocmds when no client available"] = function()
  local buf = make_buf({ "bg-red-500" })
  local augroup = vim.api.nvim_create_augroup("test_tw_lsp_au", { clear = true })
  local buf_local_opts = { __augroup_id = augroup, __event = "TextChanged" }
  local opts = tw_opts("virtualtext")

  local add_hl_called = false
  local function mock_add_highlight(...)
    add_hl_called = true
  end

  -- No tailwindcss LSP running, so lsp_highlight should return nil and set up autocmds
  local result = tailwind.lsp_highlight(buf, opts, buf_local_opts, mock_add_highlight, tailwind.cleanup, 0, -1)
  eq(nil, result)
  eq(false, add_hl_called)

  -- Check autocmds were created
  local au = vim.api.nvim_get_autocmds({ group = augroup, buffer = buf })
  eq(true, #au >= 2) -- LspAttach + LspDetach

  tailwind.cleanup(buf)
  vim.api.nvim_del_augroup_by_id(augroup)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["lsp_highlight"]["cleanup clears namespace and cache"] = function()
  local buf = make_buf({ "bg-red-500" })
  -- Place a fake extmark in tw namespace
  vim.api.nvim_buf_set_extmark(buf, tw_ns, 0, 0, { end_col = 10, hl_group = "Normal" })
  eq(1, #get_marks(buf, tw_ns))

  tailwind.cleanup(buf)
  eq(0, #get_marks(buf, tw_ns))
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["lsp_highlight"]["autocmds only created once"] = function()
  local buf = make_buf({ "bg-red-500" })
  local augroup = vim.api.nvim_create_augroup("test_tw_once", { clear = true })
  local buf_local_opts = { __augroup_id = augroup, __event = "TextChanged" }
  local opts = tw_opts("virtualtext")
  local noop = function() end

  -- Call twice
  tailwind.lsp_highlight(buf, opts, buf_local_opts, noop, tailwind.cleanup, 0, -1)
  tailwind.lsp_highlight(buf, opts, buf_local_opts, noop, tailwind.cleanup, 0, -1)

  local au = vim.api.nvim_get_autocmds({ group = augroup, buffer = buf })
  -- Should still be exactly 2 (LspAttach + LspDetach), not 4
  eq(2, #au)

  tailwind.cleanup(buf)
  vim.api.nvim_del_augroup_by_id(augroup)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["lsp_highlight"]["invalid buffer returns nil"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_delete(buf, { force = true })
  local result = tailwind.lsp_highlight(buf, {}, {}, function() end, function() end, 0, -1)
  eq(nil, result)
end

-- Priority with tailwind_lsp --------------------------------------------------

T["tw_lsp priority"] = new_set()

T["tw_lsp priority"]["lsp flag uses higher priority"] = function()
  local default_prio = (vim.hl and vim.hl.priorities and vim.hl.priorities.diagnostics) or 150
  local lsp_prio = (vim.hl and vim.hl.priorities and vim.hl.priorities.user) or 200

  local buf = make_buf({ "bg-red-500" })
  local opts = tw_opts("background")
  local data = make_lsp_data({ { line = 0, col_start = 0, col_end = 10, hex = "ef4444" } })

  -- Without tailwind_lsp
  local ns1 = vim.api.nvim_create_namespace("test_tw_prio_default")
  buffer.add_highlight(buf, ns1, 0, -1, data, opts)
  local marks1 = get_marks(buf, ns1)
  eq(default_prio, marks1[1][4].priority)

  -- With tailwind_lsp
  local ns2 = vim.api.nvim_create_namespace("test_tw_prio_lsp")
  buffer.add_highlight(buf, ns2, 0, -1, data, opts, { tailwind_lsp = true })
  local marks2 = get_marks(buf, ns2)
  eq(lsp_prio, marks2[1][4].priority)

  eq(true, lsp_prio > default_prio)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["tw_lsp priority"]["custom lsp priority from opts"] = function()
  local buf = make_buf({ "bg-red-500" })
  local opts = tw_opts("background", { priority = 300 })
  -- resolve so display.priority.lsp is set
  opts = config.resolve_options(opts)
  opts.display.priority.lsp = 300
  local ns = vim.api.nvim_create_namespace("test_tw_prio_custom")
  local data = make_lsp_data({ { line = 0, col_start = 0, col_end = 10, hex = "ef4444" } })
  buffer.add_highlight(buf, ns, 0, -1, data, opts, { tailwind_lsp = true })
  local marks = get_marks(buf, ns)
  eq(300, marks[1][4].priority)
  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
