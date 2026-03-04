---@mod colorizer.usercmds User Commands
---@brief [[
---This module provides functions for creating user commands for the Colorizer plugin in Neovim.
---It allows the creation of commands to attach, detach, reload, and toggle the Colorizer functionality on buffers.
---Available commands are:
---- `ColorizerAttachToBuffer`: Attaches Colorizer to the current buffer
---- `ColorizerDetachFromBuffer`: Detaches Colorizer from the current buffer
---- `ColorizerReloadAllBuffers`: Reloads Colorizer for all buffers
---- `ColorizerToggle`: Toggles Colorizer attachment to the buffer
---@brief ]]
local M = {}

--- Create user commands for Colorizer based on the given command list.
-- This function defines and registers Colorizer commands based on the provided list.
---@param cmds table|boolean A list of command names to create or `true` to create all available commands
function M.make(cmds)
  if not cmds then
    return
  end
  local c = require("colorizer")
  local cmd_defs = {
    ColorizerAttachToBuffer = c.attach_to_buffer,
    ColorizerDetachFromBuffer = c.detach_from_buffer,
    ColorizerReloadAllBuffers = c.reload_all_buffers,
    ColorizerToggle = function()
      if not c.is_buffer_attached() then
        c.attach_to_buffer()
      else
        c.detach_from_buffer()
      end
    end,
  }

  if type(cmds) == "boolean" and cmds then
    cmds = vim.tbl_keys(cmd_defs)
  end
  if type(cmds) ~= "table" then
    return
  end
  for _, cmd in ipairs(cmds) do
    local fn = cmd_defs[cmd]
    if fn then
      vim.api.nvim_create_user_command(cmd, function()
        fn()
      end, {})
    end
  end
end

return M
