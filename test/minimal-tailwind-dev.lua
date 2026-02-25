-- Minimal config for troubleshooting Tailwind CSS highlighting (local dev colorizer)
-- Run: make minimal-tailwind-dev
--
-- Dependencies are installed automatically via npm in test/tailwind/

local settings = {
  use_remote = false, -- Use local git directory for colorizer
  base_dir = "../colorizer_tailwind", -- Directory to clone lazy.nvim (relative to test/tailwind/)
  local_plugin_dir = os.getenv("HOME") .. "/git/nvim-colorizer.lua",
  tailwind_mode = "lsp", -- "normal" (trie names), "lsp" (LSP documentColor), or "both"
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

-- Configure tailwindcss LSP using local language server from node_modules
table.insert(settings.plugins, {
  "neovim/nvim-lspconfig",
  config = function()
    vim.lsp.config("tailwindcss", {
      cmd = { "./node_modules/.bin/tailwindcss-language-server", "--stdio" },
    })
    vim.lsp.enable("tailwindcss")
  end,
})

-- Configure colorizer
local function configure_colorizer()
  vim.opt.termguicolors = true
  require("colorizer").setup({
    filetypes = { "*" },
    user_default_options = {
      names = false,
      tailwind = settings.tailwind_mode,
      mode = "background",
      virtualtext = "■",
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
