---@mod colorizer.constants Constants
---@brief [[
---This module provides constants that are required across the application.
---@brief ]]
local M = {}

--- Plugin name
M.plugin = {
  name = "colorizer",
}

--- Namespaces used for colorizing
-- - default - Default namespace
-- - tailwind - Namespace used for creating extmarks to prevent tailwind name parsing from overwriting tailwind lsp highlights
M.namespace = {
  default = vim.api.nvim_create_namespace(M.plugin.name),
  tailwind_lsp = vim.api.nvim_create_namespace(M.plugin.name .. "_tailwind_lsp"),
}

--- Autocommand group for setting up Colorizer
M.autocmd = {
  setup = "ColorizerSetup",
  bo_type_ac = {
    filetype = "FileType",
    buftype = "BufWinEnter",
  },
}

--- Highlight mode names.  Used to create highlight names to be used with vim.api.nvim_buf_set_extmark
-- - background - Background mode
-- - foreground - Foreground mode
-- - virtualtext - Virtual text mode
M.highlight_mode_names = {
  background = "mb",
  foreground = "mf",
  virtualtext = "mv",
}

--- Byte values for commonly matched characters
M.bytes = {
  hash = 0x23,   -- '#'
  dollar = 0x24, -- '$'
  x = 0x78,      -- 'x'
}

--- Miscellaneous constants
M.defaults = {
  virtualtext = "■",
}

return M
