local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local usercmds = require("colorizer.usercmds")

local T = new_set({
  hooks = {
    pre_case = function()
      -- Clean up any previously created commands
      for _, name in ipairs({
        "ColorizerAttachToBuffer",
        "ColorizerDetachFromBuffer",
        "ColorizerReloadAllBuffers",
        "ColorizerToggle",
      }) do
        pcall(vim.api.nvim_del_user_command, name)
      end
    end,
  },
})

-- Helper: check if a user command exists
local function cmd_exists(name)
  local cmds = vim.api.nvim_get_commands({})
  return cmds[name] ~= nil
end

-- make() basics ---------------------------------------------------------------

T["make()"] = new_set()

T["make()"]["true creates all four commands"] = function()
  -- Need colorizer loaded for the commands to reference
  require("colorizer").setup()
  usercmds.make(true)
  eq(true, cmd_exists("ColorizerAttachToBuffer"))
  eq(true, cmd_exists("ColorizerDetachFromBuffer"))
  eq(true, cmd_exists("ColorizerReloadAllBuffers"))
  eq(true, cmd_exists("ColorizerToggle"))
end

T["make()"]["false creates no commands"] = function()
  usercmds.make(false)
  eq(false, cmd_exists("ColorizerAttachToBuffer"))
  eq(false, cmd_exists("ColorizerDetachFromBuffer"))
  eq(false, cmd_exists("ColorizerReloadAllBuffers"))
  eq(false, cmd_exists("ColorizerToggle"))
end

T["make()"]["nil creates no commands"] = function()
  usercmds.make(nil)
  eq(false, cmd_exists("ColorizerAttachToBuffer"))
end

T["make()"]["table arg still creates all commands (wrap side effect)"] = function()
  -- Note: wrap() creates commands as a side effect of building cmd_list,
  -- so any truthy arg creates all commands regardless of list contents
  require("colorizer").setup({ user_commands = false })
  usercmds.make({ "ColorizerToggle" })
  eq(true, cmd_exists("ColorizerToggle"))
  eq(true, cmd_exists("ColorizerAttachToBuffer"))
end

T["make()"]["setup creates commands by default"] = function()
  require("colorizer").setup()
  eq(true, cmd_exists("ColorizerAttachToBuffer"))
  eq(true, cmd_exists("ColorizerToggle"))
end

return T
