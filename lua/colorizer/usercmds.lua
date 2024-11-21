--- This module provides functions for creating user commands for the Colorizer plugin in Neovim.
-- It allows the creation of commands to attach, detach, reload, and toggle the Colorizer functionality on buffers.
-- @module colorizer.usercmds

local M = {}

--- Helper function to wrap a command function in a Neovim user command.
-- Creates a user command with the given name and function.
-- @param name string The name of the command to create
-- @param f function The function to execute when the command is run
local wrap = function(name, f)
  vim.api.nvim_create_user_command(name, function()
    f()
  end, {})
end

--- Create user commands for Colorizer based on the given command list.
-- This function defines and registers Colorizer commands based on the provided list.
-- Available commands are:
-- - `ColorizerAttachToBuffer`: Attaches Colorizer to the current buffer
-- - `ColorizerDetachFromBuffer`: Detaches Colorizer from the current buffer
-- - `ColorizerReloadAllBuffers`: Reloads Colorizer for all buffers
-- - `ColorizerToggle`: Toggles Colorizer attachment to the buffer
-- @param cmds table|boolean A list of command names to create or `true` to create all available commands
function M.make(cmds)
  if not cmds then
    return
  end
  local c = require("colorizer")
  local cmd_list = {
    ColorizerAttachToBuffer = wrap("ColorizerAttachToBuffer", c.attach_to_buffer),
    ColorizerDetachFromBuffer = wrap("ColorizerDetachFromBuffer", c.detach_from_buffer),
    ColorizerReloadAllBuffers = wrap("ColorizerReloadAllBuffers", c.reload_all_buffers),
    ColorizerToggle = wrap("ColorizerToggle", function()
      if c.is_buffer_attached() < 0 then
        c.attach_to_buffer()
      else
        c.detach_from_buffer()
      end
    end),
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
