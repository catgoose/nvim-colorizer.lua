-- Run this file as `nvim --clean -u minimal.lua`
local base_dir = "colorizer_issue"
local use_remote = false
local local_plugin_dir = os.getenv("HOME") .. "/git/nvim-colorizer.lua"

local function clone_repo_if_missing(name, url, dir)
  local install_path = vim.fn.fnamemodify(dir .. "/" .. name, ":p")
  if vim.fn.isdirectory(install_path) == 0 then
    vim.fn.system({ "git", "clone", "--depth=1", url, install_path })
  end
  vim.opt.runtimepath:append(install_path)
end

if use_remote then
  local remote_plugins = {
    colorizer = "https://github.com/NvChad/nvim-colorizer.lua",
    kanagawa = "https://github.com/rebelot/kanagawa.nvim",
  }
  for name, url in pairs(remote_plugins) do
    clone_repo_if_missing(name, url, base_dir)
  end
else
  local remote_plugins = {
    kanagawa = "https://github.com/rebelot/kanagawa.nvim",
  }
  for name, url in pairs(remote_plugins) do
    clone_repo_if_missing(name, url, base_dir)
  end
  if vim.fn.isdirectory(local_plugin_dir) == 1 then
    vim.opt.runtimepath:append(local_plugin_dir)
  else
    vim.notify("Local plugin directory not found: " .. local_plugin_dir, vim.log.levels.ERROR)
  end
end

local function get_opts(file_path)
  local opts
  local success, err = pcall(function()
    opts = dofile(file_path)
  end)
  if not success then
    vim.notify("Error reloading file: " .. err, vim.log.levels.ERROR)
    return
  end
  if not opts or type(opts) ~= "table" then
    vim.notify("Invalid options in " .. file_path, vim.log.levels.ERROR)
    return
  end
  return opts
end

-- Configure setup opts
local setup_opts = get_opts("expect.txt")
require("colorizer").setup(setup_opts)

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "expect.txt",
  callback = function(evt)
    vim.schedule(function()
      local opts = get_opts(evt.match)
      if not opts then
        return
      end
      opts = opts.user_default_options
      require("colorizer").detach_from_buffer(evt.buf)
      require("colorizer").attach_to_buffer(evt.buf, opts)
      vim.notify("Colorizer reloaded with updated options from " .. evt.match, vim.log.levels.INFO)
    end)
  end,
})

vim.cmd.colorscheme("kanagawa")
vim.cmd.edit("expect.txt")

-- ADD INIT.LUA SETTINGS _NECESSARY_ FOR REPRODUCING THE ISSUE
