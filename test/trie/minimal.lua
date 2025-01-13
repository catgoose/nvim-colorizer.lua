local M = {}

function M.setup(opts)
  opts = opts or {}
  opts = vim.tbl_extend("keep", opts, {
    use_remote = true,
    base_dir = "colorizer_trie",
    local_plugin_dir = os.getenv("HOME") .. "/git/nvim-colorizer.lua",
    plugins = {},
  })

  if not vim.loop.fs_stat(opts.base_dir) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "https://github.com/folke/lazy.nvim.git",
      "--branch=stable",
      opts.base_dir,
    })
  end
  vim.opt.rtp:prepend(opts.base_dir)

  local function add_colorizer()
    local base_config = {
      event = "BufReadPre",
      config = false,
    }
    if opts.use_remote then
      table.insert(
        opts.plugins,
        vim.tbl_extend("force", base_config, {
          "catgoose/nvim-colorizer.lua",
          url = "https://github.com/catgoose/nvim-colorizer.lua",
        })
      )
    else
      local local_dir = opts.local_plugin_dir
      if vim.fn.isdirectory(local_dir) == 1 then
        vim.opt.rtp:append(local_dir)
        table.insert(
          opts.plugins,
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
  lazy.setup(opts.plugins)
end

return M
