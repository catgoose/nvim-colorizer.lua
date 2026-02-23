local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local config = require("colorizer.config")

local T = new_set({
  hooks = {
    pre_case = function()
      -- Reset config state before each test
      config.get_setup_options(nil)
    end,
  },
})

-- apply_alias_options ---------------------------------------------------------

T["apply_alias_options"] = new_set()

T["apply_alias_options"]["css enables names, hex formats, and fn parsers"] = function()
  local opts = config.apply_alias_options({ css = true })
  eq(true, opts.names)
  eq(true, opts.RGB)
  eq(true, opts.RGBA)
  eq(true, opts.RRGGBB)
  eq(true, opts.RRGGBBAA)
  eq(true, opts.hsl_fn)
  eq(true, opts.rgb_fn)
  eq(true, opts.oklch_fn)
end

T["apply_alias_options"]["css_fn enables only function parsers"] = function()
  local opts = config.apply_alias_options({ css_fn = true })
  eq(true, opts.hsl_fn)
  eq(true, opts.rgb_fn)
  eq(true, opts.oklch_fn)
end

T["apply_alias_options"]["individual options override css alias"] = function()
  local opts = config.apply_alias_options({ css = true, names = false })
  eq(false, opts.names)
  -- Other css options should still be enabled
  eq(true, opts.RGB)
end

T["apply_alias_options"]["tailwind true becomes 'normal'"] = function()
  local opts = config.apply_alias_options({ tailwind = true })
  eq("normal", opts.tailwind)
end

T["apply_alias_options"]["invalid tailwind value resets to default"] = function()
  local opts = config.apply_alias_options({ tailwind = "invalid" })
  eq(false, opts.tailwind)
end

T["apply_alias_options"]["virtualtext_inline true becomes 'after'"] = function()
  local opts = config.apply_alias_options({ virtualtext_inline = true })
  eq("after", opts.virtualtext_inline)
end

T["apply_alias_options"]["virtualtext_inline invalid value resets to default"] = function()
  local opts = config.apply_alias_options({ virtualtext_inline = "center" })
  eq(false, opts.virtualtext_inline)
end

T["apply_alias_options"]["virtualtext_inline 'before' is accepted"] = function()
  local opts = config.apply_alias_options({ virtualtext_inline = "before" })
  eq("before", opts.virtualtext_inline)
end

-- get_setup_options -----------------------------------------------------------

T["get_setup_options"] = new_set()

T["get_setup_options"]["returns default options when called with nil"] = function()
  local opts = config.get_setup_options(nil)
  eq(true, type(opts) == "table")
  eq(true, type(opts.user_default_options) == "table")
  eq(true, type(opts.filetypes) == "table")
end

T["get_setup_options"]["merges user options"] = function()
  local opts = config.get_setup_options({
    user_default_options = { RGB = false },
  })
  eq(false, opts.user_default_options.RGB)
end

T["get_setup_options"]["filetypes default to {'*'}"] = function()
  local opts = config.get_setup_options(nil)
  eq("*", opts.filetypes[1])
end

T["get_setup_options"]["custom filetypes are preserved"] = function()
  local opts = config.get_setup_options({
    filetypes = { "lua", "css" },
  })
  eq("lua", opts.filetypes[1])
  eq("css", opts.filetypes[2])
end

return T
