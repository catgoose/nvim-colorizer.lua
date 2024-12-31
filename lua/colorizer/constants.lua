--- This module provides constants that are required across the application
-- @module colorizer.constants
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
  tailwind = vim.api.nvim_create_namespace(M.plugin.name .. "_tailwind"),
}

--- Autocommand group for setting up Colorizer
M.autocmd = {
  setup = "ColorizerSetup",
}

--- Highlight mode names.  Used to create highlight names to be used with vim.api.nvim_buf_add_highlight
-- - background - Background mode
-- - foreground - Foreground mode
-- - virtualtext - Virtual text mode
M.highlight_mode_names = {
  background = "mb",
  foreground = "mf",
  virtualtext = "mv",
}

return M