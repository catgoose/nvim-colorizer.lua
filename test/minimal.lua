-- Run this file as `nvim --clean -u minimal.lua`

-- local local_plugin_dir = os.getenv("HOME") .. "/git/nvim-colorizer.lua"
-- if vim.fn.isdirectory(local_plugin_dir) == 1 then
--   vim.opt.runtimepath:append(local_plugin_dir)
-- else
--   vim.notify("Local plugin directory not found: " .. local_plugin_dir, vim.log.levels.ERROR)
-- end

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
local setup_opts = {
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
    tailwind = "normal",
    sass = {
      enable = false,
      parsers = { "css" },
    },
    virtualtext = "■",
    virtualtext_inline = false,
    virtualtext_mode = "foreground",
    always_update = false,
  },
  buftypes = { "!prompt", "!popup" },
  user_commands = true,
}
require("colorizer").setup(setup_opts)

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "expect.txt", -- Ensure this matches your file name
  callback = function(evt)
    vim.schedule(function()
      local file_path = evt.match

      if not file_path or file_path == "" then
        vim.notify("Could not determine the file path", vim.log.levels.ERROR)
        return
      end

      local opts
      local success, err = pcall(function()
        opts = dofile(file_path) -- Dynamically execute the saved file
      end)

      if not success then
        vim.notify("Error reloading file: " .. err, vim.log.levels.ERROR)
        return
      end

      if not opts or type(opts) ~= "table" then
        vim.notify("Invalid options in " .. file_path, vim.log.levels.ERROR)
        return
      end

      require("colorizer").detach_from_buffer(evt.buf)
      require("colorizer").attach_to_buffer(evt.buf, opts)

      vim.notify("Colorizer reloaded with updated options from " .. file_path, vim.log.levels.INFO)
    end)
  end,
})

vim.cmd.edit("tailwind.html")
vim.schedule(function()
  vim.cmd("leftabove vsplit expect.txt")
end)

-- ADD INIT.LUA SETTINGS _NECESSARY_ FOR REPRODUCING THE ISSUE
