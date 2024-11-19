-- Run this file as `nvim --clean -u minimal.lua expect.txt`

for name, url in pairs({
  colorizer = "https://github.com/NvChad/nvim-colorizer.lua",
}) do
  local install_path = vim.fn.fnamemodify("colorizer_issue/" .. name, ":p")
  if vim.fn.isdirectory(install_path) == 0 then
    vim.fn.system({ "git", "clone", "--depth=1", url, install_path })
  end
  vim.opt.runtimepath:append(install_path)
end

-- Configure setup opts
local opts = {
  user_default_options = {
    RGB = true,
    RRGGBB = true,
    names = true,
    RRGGBBAA = true,
    AARRGGBB = true,
    rgb_fn = true,
    hsl_fn = true,
    css = true,
    css_fn = true,
    mode = "background",
    tailwind = "lsp",
    sass = {
      enable = false,
      parsers = { "css" },
    },
    virtualtext = "■",
  },
  buftypes = { "!prompt", "!popup" },
  user_commands = true,
}
require("colorizer").setup(opts)

-- ADD INIT.LUA SETTINGS _NECESSARY_ FOR REPRODUCING THE ISSUE
