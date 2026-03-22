-- Minimal config for troubleshooting CSS custom property (var()) highlighting (local dev colorizer)
-- Run: make minimal-css-var-dev
--
-- Dependencies are installed automatically via npm in test/css-var/

local settings = {
  use_remote = false, -- Use local git directory for colorizer
  base_dir = "../colorizer_css_var", -- Directory to clone lazy.nvim (relative to test/css-var/)
  local_plugin_dir = os.getenv("HOME") .. "/git/nvim-colorizer.lua",
  plugins = {},
}

if not (vim.uv or vim.loop).fs_stat(settings.base_dir) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    settings.base_dir,
  })
end
vim.opt.rtp:prepend(settings.base_dir)

-- Configure colorizer
local function configure_colorizer()
  vim.opt.termguicolors = true
  require("colorizer").setup({
    filetypes = { "*" },
    options = {
      parsers = {
        css = true, -- enables hex, rgb, hsl, oklch, names, css_var (+ @import scanning)
      },
      display = {
        mode = "background",
        virtualtext = { char = "■" },
      },
    },
  })
end

local function add_colorizer()
  local base_config = {
    event = "BufReadPre",
    config = configure_colorizer,
  }
  if settings.use_remote then
    table.insert(
      settings.plugins,
      vim.tbl_extend("force", base_config, {
        "catgoose/nvim-colorizer.lua",
        url = "https://github.com/catgoose/nvim-colorizer.lua",
      })
    )
  else
    local local_dir = settings.local_plugin_dir
    if vim.fn.isdirectory(local_dir) == 1 then
      vim.opt.rtp:append(local_dir)
      table.insert(
        settings.plugins,
        vim.tbl_extend("force", base_config, {
          dir = local_dir,
          lazy = false,
        })
      )
    else
      vim.notify("Local plugin directory not found: " .. local_dir, vim.log.levels.ERROR)
    end
  end
end

-- Initialize and setup lazy.nvim
local ok, lazy = pcall(require, "lazy")
if not ok then
  vim.notify("Failed to require lazy.nvim", vim.log.levels.ERROR)
  return
end

add_colorizer()
lazy.setup(settings.plugins)
