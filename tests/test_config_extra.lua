local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local config = require("colorizer.config")

local T = new_set({
  hooks = {
    pre_case = function()
      config.get_setup_options(nil)
    end,
  },
})

-- set_bo_value / get_bo_options round-trip -------------------------------------

T["set_bo_value + get_bo_options"] = new_set()

T["set_bo_value + get_bo_options"]["round-trip for filetype"] = function()
  local opts = { names = true, RGB = true }
  config.set_bo_value("filetype", "lua", opts)
  local result = config.get_bo_options("filetype", "", "lua")
  eq(true, result ~= nil)
  eq(true, result.names)
  eq(true, result.RGB)
end

T["set_bo_value + get_bo_options"]["round-trip for buftype"] = function()
  local opts = { names = false, RRGGBB = true }
  config.set_bo_value("buftype", "nofile", opts)
  local result = config.get_bo_options("buftype", "nofile", "")
  eq(true, result ~= nil)
  eq(true, result.RRGGBB)
end

T["set_bo_value + get_bo_options"]["filetype preferred over buftype"] = function()
  local ft_opts = { names = true }
  local bt_opts = { names = false }
  config.set_bo_value("filetype", "css", ft_opts)
  config.set_bo_value("filetype", "nofile", bt_opts)
  local result = config.get_bo_options("filetype", "nofile", "css")
  eq(true, result.names)
end

-- new_bo_options --------------------------------------------------------------

T["new_bo_options"] = new_set()

T["new_bo_options"]["returns default options for unknown filetype"] = function()
  config.get_setup_options(nil)
  local buf = vim.api.nvim_create_buf(false, true)
  -- Set a filetype that has no cached options
  vim.api.nvim_set_option_value("filetype", "zzz_unknown_ft", { buf = buf })
  local result = config.new_bo_options(buf, "filetype")
  eq(true, result ~= nil)
  -- Should match the canonical new-format options
  eq(config.options.options.parsers.names.enable, result.parsers.names.enable)
  eq(config.options.options.parsers.hex.rgb, result.parsers.hex.rgb)
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- names_custom handling -------------------------------------------------------

T["names_custom"] = new_set()

T["names_custom"]["table gets hashed into names_custom_hashed"] = function()
  local opts = config.apply_alias_options({
    names_custom = { myred = "#ff0000" },
  })
  eq(true, opts.names_custom_hashed ~= nil and opts.names_custom_hashed ~= false)
  eq("table", type(opts.names_custom_hashed))
  eq(true, opts.names_custom_hashed.hash ~= nil)
  eq(true, opts.names_custom_hashed.names ~= nil)
end

T["names_custom"]["empty table becomes false"] = function()
  local opts = config.apply_alias_options({
    names_custom = {},
  })
  eq(false, opts.names_custom)
  -- names_custom_hashed should not be set (stays as default false)
  eq(true, not opts.names_custom_hashed)
end

T["names_custom"]["function result gets hashed"] = function()
  local opts = config.apply_alias_options({
    names_custom = function()
      return { myblue = "#0000ff" }
    end,
  })
  eq(true, opts.names_custom_hashed ~= nil and opts.names_custom_hashed ~= false)
  eq("myblue", next(opts.names_custom_hashed.names))
end

-- hooks validation ------------------------------------------------------------

T["hooks"] = new_set()

T["hooks"]["disable_line_highlight non-function becomes false (legacy)"] = function()
  local opts = config.apply_alias_options({
    hooks = { disable_line_highlight = "not a function" },
  })
  eq(false, opts.hooks.disable_line_highlight)
end

T["hooks"]["disable_line_highlight true becomes false (legacy)"] = function()
  local opts = config.apply_alias_options({
    hooks = { disable_line_highlight = true },
  })
  eq(false, opts.hooks.disable_line_highlight)
end

T["hooks"]["disable_line_highlight function is preserved (legacy)"] = function()
  local fn = function()
    return true
  end
  local opts = config.apply_alias_options({
    hooks = { disable_line_highlight = fn },
  })
  eq(fn, opts.hooks.disable_line_highlight)
end

-- mode validation -------------------------------------------------------------

T["mode validation"] = new_set()

T["mode validation"]["invalid mode resets to background"] = function()
  local opts = config.apply_alias_options({ mode = "invalid_mode" })
  eq("background", opts.mode)
end

T["mode validation"]["'foreground' is accepted"] = function()
  local opts = config.apply_alias_options({ mode = "foreground" })
  eq("foreground", opts.mode)
end

T["mode validation"]["'virtualtext' is accepted"] = function()
  local opts = config.apply_alias_options({ mode = "virtualtext" })
  eq("virtualtext", opts.mode)
end

-- virtualtext_mode validation -------------------------------------------------

T["virtualtext_mode validation"] = new_set()

T["virtualtext_mode validation"]["invalid virtualtext_mode resets to foreground"] = function()
  local opts = config.apply_alias_options({ virtualtext_mode = "invalid" })
  eq("foreground", opts.virtualtext_mode)
end

T["virtualtext_mode validation"]["'background' is accepted"] = function()
  local opts = config.apply_alias_options({ virtualtext_mode = "background" })
  eq("background", opts.virtualtext_mode)
end

return T
