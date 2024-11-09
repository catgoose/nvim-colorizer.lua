--@module colorizer.usercmds
local M = {}

local wrap = function(name, f)
  vim.api.nvim_create_user_command(name, f, {})
end

--- Create User Commands
---@param cmds table|boolean: List of commands
function M.make(cmds)
  if not cmds then
    return
  end
  local cmd_list = {
    ColorizerAttachToBuffer = function()
      wrap("ColorizerAttachToBuffer", require("colorizer").attach_to_buffer)
    end,
    ColorizerDetachFromBuffer = function()
      wrap("ColorizerDetachFromBuffer", require("colorizer").detach_from_buffer)
    end,
    ColorizerReloadAllBuffers = function()
      wrap("ColorizerReloadAllBuffers", require("colorizer").reload_all_buffers)
    end,
    ColorizerToggle = function()
      wrap("ColorizerToggle", function()
        local c = require("colorizer")
        if c.is_buffer_attached() then
          c.detach_from_buffer()
        else
          c.attach_to_buffer()
        end
      end)
    end,
  }

  if type(cmds) == "boolean" and cmds then
    cmds = vim.tbl_keys(cmd_list)
  end
  if type(cmds) ~= "table" then
    return
  end
  for _, cmd in ipairs(cmds) do
    if cmd_list[cmd] then
      cmd_list[cmd]()
    end
  end
end

return M
