local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local const = require("colorizer.constants")

local T = new_set()

-- Namespace -------------------------------------------------------------------

T["namespace"] = new_set()

T["namespace"]["default namespace exists"] = function()
  eq("number", type(const.namespace.default))
  eq(true, const.namespace.default > 0)
end

T["namespace"]["tailwind_lsp namespace exists"] = function()
  eq("number", type(const.namespace.tailwind_lsp))
  eq(true, const.namespace.tailwind_lsp > 0)
end

T["namespace"]["namespaces are distinct"] = function()
  eq(true, const.namespace.default ~= const.namespace.tailwind_lsp)
end

-- Plugin name -----------------------------------------------------------------

T["plugin"] = new_set()

T["plugin"]["name is 'colorizer'"] = function()
  eq("colorizer", const.plugin.name)
end

-- Autocmd constants -----------------------------------------------------------

T["autocmd"] = new_set()

T["autocmd"]["setup group name"] = function()
  eq("ColorizerSetup", const.autocmd.setup)
end

T["autocmd"]["filetype maps to FileType"] = function()
  eq("FileType", const.autocmd.bo_type_ac.filetype)
end

T["autocmd"]["buftype maps to BufWinEnter"] = function()
  eq("BufWinEnter", const.autocmd.bo_type_ac.buftype)
end

-- Highlight mode names --------------------------------------------------------

T["highlight_mode_names"] = new_set()

T["highlight_mode_names"]["background is 'mb'"] = function()
  eq("mb", const.highlight_mode_names.background)
end

T["highlight_mode_names"]["foreground is 'mf'"] = function()
  eq("mf", const.highlight_mode_names.foreground)
end

T["highlight_mode_names"]["virtualtext is 'mv'"] = function()
  eq("mv", const.highlight_mode_names.virtualtext)
end

-- Bytes -----------------------------------------------------------------------

T["bytes"] = new_set()

T["bytes"]["hash is 0x23"] = function()
  eq(0x23, const.bytes.hash)
  eq(string.byte("#"), const.bytes.hash)
end

T["bytes"]["dollar is 0x24"] = function()
  eq(0x24, const.bytes.dollar)
  eq(string.byte("$"), const.bytes.dollar)
end

T["bytes"]["x is 0x78"] = function()
  eq(0x78, const.bytes.x)
  eq(string.byte("x"), const.bytes.x)
end

-- Defaults --------------------------------------------------------------------

T["defaults"] = new_set()

T["defaults"]["virtualtext character"] = function()
  eq(true, type(const.defaults.virtualtext) == "string")
  eq(true, #const.defaults.virtualtext > 0)
end

return T
