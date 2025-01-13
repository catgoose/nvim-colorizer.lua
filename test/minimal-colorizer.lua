-- Run this file as `nvim --clean -u minimal-colorizer.lua`

local settings = {
  use_remote = true, -- Use colorizer master or local git directory
  base_dir = "colorizer_minimal", -- Directory to clone lazy.nvim
  local_plugin_dir = os.getenv("HOME") .. "/git/nvim-colorizer.lua", -- Local git directory for colorizer.  Used if use_remote is false
  expect = "expect.lua",
  plugins = { -- add any additional plugins
    {
      "rebelot/kanagawa.nvim",
      url = "https://github.com/rebelot/kanagawa.nvim",
      config = function()
        vim.cmd.colorscheme("kanagawa")
      end,
    },
  },
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

-- Load options returned from lua file
local function load_options(file_path)
  local success, opts = pcall(dofile, file_path)
  if not success or type(opts) ~= "table" then
    vim.notify("Failed to load options from " .. file_path, vim.log.levels.ERROR)
    return
  end
  return opts
end

-- Configure colorizer plugin
local function configure_colorizer()
  vim.opt.termguicolors = true
  local opts = load_options(settings.expect)
  if opts then
    require("colorizer").setup(opts)
  else
    vim.notify(
      string.format("Could not load colorizer options from %s", settings.expect),
      vim.log.levels.WARN
    )
  end
end

local function add_colorizer()
  local base_config = {
    event = "BufReadPre",
    cmd = {
      "ColorizerToggle",
      "ColorizerAttachToBuffer",
      "ColorizerDetachFromBuffer",
      "ColorizerReloadAllBuffers",
    },
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

require("colorizer").reload_on_save(settings.expect)
vim.cmd.edit(settings.expect)
-- ADD INIT.LUA SETTINGS _NECESSARY_ FOR REPRODUCING THE ISSUE
