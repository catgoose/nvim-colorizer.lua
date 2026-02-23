local M = {}

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
local deps = root .. "/deps"
local mini = deps .. "/mini.nvim"

if not vim.uv.fs_stat(mini) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/echasnovski/mini.nvim",
    mini,
  })
end

vim.opt.rtp:prepend(mini)
vim.opt.rtp:prepend(root)
vim.o.termguicolors = true

require("mini.test").setup()

M.expect = MiniTest.expect
M.eq = MiniTest.expect.equality
M.new_set = MiniTest.new_set

return M
