local command = function(name, f)
  vim.api.nvim_create_user_command(name, f, {})
end

local M = {}

--- Create User Commands
---@param cmds table|boolean: List of commands
function M.make(cmds)
  if not cmds then
    return
  end
  local cmd_m = {
    ColorizerAttachToBuffer = function()
      command("ColorizerAttachToBuffer", require("colorizer").attach_to_buffer)
    end,
    ColorizerDetachFromBuffer = function()
      command("ColorizerDetachFromBuffer", require("colorizer").detach_from_buffer)
    end,
    ColorizerReloadAllBuffers = function()
      command("ColorizerReloadAllBuffers", require("colorizer").reload_all_buffers)
    end,
    ColorizerToggle = function()
      command("ColorizerToggle", function()
        local c = require "colorizer"
        if c.is_buffer_attached() then
          c.detach_from_buffer()
        else
          c.attach_to_buffer()
        end
      end)
    end,
  }

  if type(cmds) == "boolean" and cmds then
    cmds = vim.tbl_keys(cmd_m)
  end
  if type(cmds) ~= "table" then
    return
  end
  for _, cmd in ipairs(cmds) do
    if cmd_m[cmd] then
      cmd_m[cmd]()
    end
  end
end

return M
