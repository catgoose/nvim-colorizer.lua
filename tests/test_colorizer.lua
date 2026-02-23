local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local colorizer = require("colorizer")
local config = require("colorizer.config")
local const = require("colorizer.constants")
local matcher = require("colorizer.matcher")
local names = require("colorizer.parser.names")
local buffer = require("colorizer.buffer")

local T = new_set({
  hooks = {
    pre_case = function()
      matcher.reset_cache()
      names.reset_cache()
      buffer.reset_cache()
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

-- setup() ---------------------------------------------------------------------

T["setup()"] = new_set()

T["setup()"]["with default opts doesn't error"] = function()
  colorizer.setup()
  eq(true, true) -- reaching here means no error
end

T["setup()"]["with custom opts doesn't error"] = function()
  colorizer.setup({ user_default_options = { css = true } })
  eq(true, true)
end

-- attach / detach lifecycle ---------------------------------------------------

T["attach_to_buffer"] = new_set()

T["attach_to_buffer"]["attach then is_buffer_attached returns true"] = function()
  colorizer.setup()
  local buf = make_buf({ "#FF0000" })
  local opts = config.apply_alias_options({ RRGGBB = true })
  colorizer.attach_to_buffer(buf, opts, "buftype")
  eq(true, colorizer.is_buffer_attached(buf))
  colorizer.detach_from_buffer(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["attach_to_buffer"]["detach then is_buffer_attached returns false"] = function()
  colorizer.setup()
  local buf = make_buf({ "#FF0000" })
  local opts = config.apply_alias_options({ RRGGBB = true })
  colorizer.attach_to_buffer(buf, opts, "buftype")
  colorizer.detach_from_buffer(buf)
  eq(false, colorizer.is_buffer_attached(buf))
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- get_attached_bufnr ----------------------------------------------------------

T["get_attached_bufnr"] = new_set()

T["get_attached_bufnr"]["returns -1 for unattached buffer"] = function()
  colorizer.setup()
  local buf = make_buf({ "text" })
  eq(-1, colorizer.get_attached_bufnr(buf))
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["get_attached_bufnr"]["returns bufnr for attached buffer"] = function()
  colorizer.setup()
  local buf = make_buf({ "#FF0000" })
  local opts = config.apply_alias_options({ RRGGBB = true })
  colorizer.attach_to_buffer(buf, opts, "buftype")
  eq(buf, colorizer.get_attached_bufnr(buf))
  colorizer.detach_from_buffer(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["get_attached_bufnr"]["0 resolves to current buffer"] = function()
  colorizer.setup()
  local buf = make_buf({ "#FF0000" })
  vim.api.nvim_set_current_buf(buf)
  local opts = config.apply_alias_options({ RRGGBB = true })
  colorizer.attach_to_buffer(0, opts, "buftype")
  local result = colorizer.get_attached_bufnr(0)
  eq(buf, result)
  colorizer.detach_from_buffer(buf)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- detach_from_buffer ----------------------------------------------------------

T["detach_from_buffer"] = new_set()

T["detach_from_buffer"]["on unattached buffer returns -1"] = function()
  colorizer.setup()
  local buf = make_buf({ "text" })
  eq(-1, colorizer.detach_from_buffer(buf))
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["detach_from_buffer"]["clears extmarks after detach"] = function()
  colorizer.setup()
  local buf = make_buf({ "#FF0000" })
  local opts = config.apply_alias_options({ RRGGBB = true })
  colorizer.attach_to_buffer(buf, opts, "buftype")
  colorizer.detach_from_buffer(buf)
  local marks = vim.api.nvim_buf_get_extmarks(buf, const.namespace.default, 0, -1, {})
  eq(0, #marks)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- reload_all_buffers ----------------------------------------------------------

T["reload_all_buffers"] = new_set()

T["reload_all_buffers"]["doesn't error with no active buffers"] = function()
  colorizer.setup()
  colorizer.reload_all_buffers()
  eq(true, true)
end

return T
