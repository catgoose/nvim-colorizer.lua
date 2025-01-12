-- Run this file as `nvim --clean -u minimal-trie.lua`

local settings = {
  use_remote = true, -- Use colorizer master or local git directory
  base_dir = "colorizer_trie", -- Directory to clone lazy.nvim
  local_plugin_dir = os.getenv("HOME") .. "/git/nvim-colorizer.lua", -- Local git directory for colorizer.  Used if use_remote is false
  plugins = {},
}

if not vim.loop.fs_stat(settings.base_dir) then
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

local function add_colorizer()
  local base_config = {
    event = "BufReadPre",
    config = false,
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

dofile("print-trie.lua")

-- ADD INIT.LUA SETTINGS _NECESSARY_ FOR REPRODUCING THE ISSUE
