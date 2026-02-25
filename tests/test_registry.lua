local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local registry = require("colorizer.parser.registry")

local T = new_set({
  hooks = {
    pre_case = function()
      -- Ensure all parsers are loaded
      require("colorizer.parser")
    end,
  },
})

-- Registration -----------------------------------------------------------------

T["registration"] = new_set()

T["registration"]["all built-in parsers are registered"] = function()
  local expected = {
    "rgba_hex", "argb_hex", "xterm", "rgb", "hsl", "oklch", "names", "sass",
  }
  for _, name in ipairs(expected) do
    local spec = registry.get(name)
    eq(true, spec ~= nil, "expected parser '" .. name .. "' to be registered")
    eq(name, spec.name)
  end
end

T["registration"]["get returns nil for unknown parser"] = function()
  eq(nil, registry.get("nonexistent"))
end

-- Ordering ---------------------------------------------------------------------

T["ordering"] = new_set()

T["ordering"]["all() returns specs sorted by priority ascending"] = function()
  local all = registry.all()
  eq(true, #all >= 8, "expected at least 8 registered parsers")
  for i = 2, #all do
    eq(true, all[i].priority >= all[i - 1].priority,
      string.format("expected priority %d >= %d for %s after %s",
        all[i].priority, all[i - 1].priority, all[i].name, all[i - 1].name))
  end
end

T["ordering"]["xterm has lowest priority (first)"] = function()
  local all = registry.all()
  eq("xterm", all[1].name)
  eq(9, all[1].priority)
end

T["ordering"]["names is a fallback parser with high priority number"] = function()
  local spec = registry.get("names")
  eq("fallback", spec.dispatch.kind)
  eq(25, spec.priority)
end

-- Dispatch kinds ---------------------------------------------------------------

T["dispatch"] = new_set()

T["dispatch"]["rgba_hex is byte-dispatched on #"] = function()
  local spec = registry.get("rgba_hex")
  eq("byte", spec.dispatch.kind)
  eq(true, vim.tbl_contains(spec.dispatch.bytes, 0x23))
end

T["dispatch"]["xterm is byte+fallback"] = function()
  local spec = registry.get("xterm")
  eq("byte+fallback", spec.dispatch.kind)
end

T["dispatch"]["rgb is prefix-dispatched on rgb/rgba"] = function()
  local spec = registry.get("rgb")
  eq("prefix", spec.dispatch.kind)
  eq(true, vim.tbl_contains(spec.dispatch.prefixes, "rgb"))
  eq(true, vim.tbl_contains(spec.dispatch.prefixes, "rgba"))
end

T["dispatch"]["sass is byte-dispatched on $"] = function()
  local spec = registry.get("sass")
  eq("byte", spec.dispatch.kind)
  eq(true, vim.tbl_contains(spec.dispatch.bytes, 0x24))
end

-- Config defaults --------------------------------------------------------------

T["config_defaults"] = new_set()

T["config_defaults"]["returns defaults for parsers with config_defaults"] = function()
  local defaults = registry.config_defaults()
  -- rgb, hsl, oklch, xterm, names, sass should have defaults
  eq(true, defaults.rgb ~= nil)
  eq(false, defaults.rgb.enable)
  eq(true, defaults.names ~= nil)
  eq(false, defaults.names.enable)
  eq(true, defaults.names.lowercase)
  eq(true, defaults.sass ~= nil)
  eq(false, defaults.sass.enable)
end

T["config_defaults"]["parsers without config_defaults are omitted"] = function()
  local defaults = registry.config_defaults()
  -- rgba_hex and argb_hex have no config_defaults (controlled by hex.*)
  eq(nil, defaults.rgba_hex)
  eq(nil, defaults.argb_hex)
end

-- Spec parse function ----------------------------------------------------------

T["spec.parse"] = new_set()

T["spec.parse"]["rgb spec.parse works with ctx"] = function()
  local spec = registry.get("rgb")
  local ctx = { line = "rgb(255, 0, 0)", col = 1, prefix = "rgb" }
  local len, hex = spec.parse(ctx)
  eq(true, len ~= nil)
  eq("ff0000", hex)
end

T["spec.parse"]["oklch spec.parse works with ctx"] = function()
  local spec = registry.get("oklch")
  local ctx = { line = "oklch(0.6 0.2 30)", col = 1 }
  local len, hex = spec.parse(ctx)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["spec.parse"]["argb_hex spec.parse works with ctx"] = function()
  local spec = registry.get("argb_hex")
  local ctx = { line = "0xFF00FF text", col = 1 }
  local len, hex = spec.parse(ctx)
  eq(true, len ~= nil)
  eq("ff00ff", hex)
end

T["spec.parse"]["xterm spec.parse works with #x format"] = function()
  local spec = registry.get("xterm")
  local ctx = { line = "#x196", col = 1 }
  local len, hex = spec.parse(ctx)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["spec.parse"]["rgba_hex spec.parse works with ctx"] = function()
  local spec = registry.get("rgba_hex")
  local ctx = {
    line = "#FF0000 text",
    col = 1,
    parser_config = { valid_lengths = { [6] = true }, minlen = 6, maxlen = 6 },
  }
  local len, hex = spec.parse(ctx)
  eq(7, len)
  eq("FF0000", hex)
end

-- reset_all_caches -------------------------------------------------------------

T["reset_all_caches"] = new_set()

T["reset_all_caches"]["calls reset_cache on names parser"] = function()
  -- Just verify it doesn't error
  registry.reset_all_caches()
end

return T
