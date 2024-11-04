if vim.g.loaded_colorizer then
  return
end

local command = vim.api.nvim_create_user_command

command("ColorizerAttachToBuffer", function()
  require("colorizer").attach_to_buffer()
end, {})

-- Stop highlighting the current buffer (detach).
command("ColorizerDetachFromBuffer", function()
  require("colorizer").detach_from_buffer()
end, {})

command("ColorizerReloadAllBuffers", function()
  require("colorizer").reload_all_buffers()
end, {})

command("ColorizerToggle", function()
  local c = require "colorizer"
  if c.is_buffer_attached() then
    c.detach_from_buffer()
  else
    c.attach_to_buffer()
  end
end, {})

vim.g.loaded_colorizer = true
