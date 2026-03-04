local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local names = require("colorizer.parser.names")

local T = new_set({
  hooks = {
    pre_case = function()
      names.reset_cache()
    end,
  },
})

-- Helper to build m_opts for the names parser
local function make_names_opts(overrides)
  local defaults = {
    color_names = true,
    color_names_opts = {
      lowercase = true,
      camelcase = false,
      uppercase = false,
      strip_digits = false,
    },
  }
  if overrides then
    for k, v in pairs(overrides) do
      if type(v) == "table" and type(defaults[k]) == "table" then
        for kk, vv in pairs(v) do
          defaults[k][kk] = vv
        end
      else
        defaults[k] = v
      end
    end
  end
  return defaults
end

-- Lowercase names -------------------------------------------------------------

T["lowercase"] = new_set()

T["lowercase"]["matches 'red'"] = function()
  local opts = make_names_opts()
  local len, hex = names.parser("red", 1, opts)
  eq(3, len)
  eq("ff0000", hex)
end

T["lowercase"]["matches 'blue'"] = function()
  local opts = make_names_opts()
  local len, hex = names.parser("blue", 1, opts)
  eq(4, len)
  eq("0000ff", hex)
end

T["lowercase"]["matches 'white'"] = function()
  local opts = make_names_opts()
  local len, hex = names.parser("white", 1, opts)
  eq(5, len)
  eq("ffffff", hex)
end

T["lowercase"]["no match for 'Red' when only lowercase enabled"] = function()
  local opts = make_names_opts()
  local len = names.parser("Red", 1, opts)
  eq(nil, len)
end

-- CamelCase names -------------------------------------------------------------

T["camelcase"] = new_set()

T["camelcase"]["matches 'DeepSkyBlue'"] = function()
  local opts = make_names_opts({ color_names_opts = { camelcase = true } })
  local len, hex = names.parser("DeepSkyBlue", 1, opts)
  eq(true, len ~= nil)
  eq(true, hex ~= nil)
end

T["camelcase"]["matches 'LightBlue'"] = function()
  local opts = make_names_opts({ color_names_opts = { camelcase = true } })
  local len, hex = names.parser("LightBlue", 1, opts)
  eq(true, len ~= nil)
end

-- Uppercase names -------------------------------------------------------------

T["uppercase"] = new_set()

T["uppercase"]["matches 'RED'"] = function()
  local opts = make_names_opts({ color_names_opts = { uppercase = true } })
  local len, hex = names.parser("RED", 1, opts)
  eq(3, len)
  eq("ff0000", hex)
end

T["uppercase"]["matches 'DEEPSKYBLUE'"] = function()
  local opts = make_names_opts({ color_names_opts = { uppercase = true } })
  local len, hex = names.parser("DEEPSKYBLUE", 1, opts)
  eq(true, len ~= nil)
end

-- strip_digits ----------------------------------------------------------------

T["strip_digits"] = new_set()

T["strip_digits"]["strip_digits filters names ending with digits"] = function()
  local opts = make_names_opts({ color_names_opts = { strip_digits = true } })
  -- "gray100" is a valid vim color name; with strip_digits it should be rejected
  local len = names.parser("gray100", 1, opts)
  eq(nil, len)
end

T["strip_digits"]["without strip_digits, names with digits match"] = function()
  local opts = make_names_opts({ color_names_opts = { strip_digits = false } })
  local len, hex = names.parser("gray100", 1, opts)
  eq(true, len ~= nil)
end

-- Custom names ----------------------------------------------------------------

T["custom names"] = new_set()

T["custom names"]["matches custom name"] = function()
  local custom = { mycolor = "#ff5500" }
  local hash = require("colorizer.utils").hash_table(custom)
  local opts = make_names_opts({
    color_names = false,
    names_custom = { hash = hash, names = custom },
  })
  local len, hex = names.parser("mycolor", 1, opts)
  eq(7, len)
  eq("ff5500", hex)
end

T["custom names"]["custom name with underscore"] = function()
  local custom = { one_two = "#017dac" }
  local hash = require("colorizer.utils").hash_table(custom)
  local opts = make_names_opts({
    color_names = false,
    names_custom = { hash = hash, names = custom },
  })
  local len, hex = names.parser("one_two", 1, opts)
  eq(7, len)
  eq("017dac", hex)
end

-- Boundary checks -------------------------------------------------------------

T["boundary"] = new_set()

T["boundary"]["no match when preceded by valid color char"] = function()
  local opts = make_names_opts()
  -- 'xred' - the 'x' before 'red' is alphanumeric
  local len = names.parser("xred", 2, opts)
  eq(nil, len)
end

T["boundary"]["no match when followed by valid color char"] = function()
  local opts = make_names_opts()
  -- 'redx' - the 'x' after 'red' is alphanumeric
  local len = names.parser("redx", 1, opts)
  eq(nil, len)
end

T["boundary"]["matches when surrounded by non-color chars"] = function()
  local opts = make_names_opts()
  local len, hex = names.parser(" red ", 2, opts)
  eq(3, len)
  eq("ff0000", hex)
end

-- No match for invalid names --------------------------------------------------

T["no match invalid"] = new_set()

T["no match invalid"]["ceruleanblue does not match"] = function()
  local opts = make_names_opts({ color_names_opts = { lowercase = true, camelcase = true, uppercase = true } })
  local len = names.parser("ceruleanblue", 1, opts)
  eq(nil, len)
end

-- lookup_name() ---------------------------------------------------------------

T["lookup_name"] = new_set()

T["lookup_name"]["returns hex for valid lowercase name"] = function()
  local opts = make_names_opts()
  local hex = names.lookup_name("red", opts)
  eq("ff0000", hex)
end

T["lookup_name"]["returns hex for valid camelcase name"] = function()
  local opts = make_names_opts({ color_names_opts = { camelcase = true } })
  local hex = names.lookup_name("DeepSkyBlue", opts)
  eq("00bfff", hex)
end

T["lookup_name"]["returns nil for unrecognized name"] = function()
  local opts = make_names_opts()
  local hex = names.lookup_name("notacolor", opts)
  eq(nil, hex)
end

T["lookup_name"]["returns nil when color_names disabled"] = function()
  local opts = make_names_opts({ color_names = false })
  local hex = names.lookup_name("red", opts)
  eq(nil, hex)
end

T["lookup_name"]["returns nil for CamelCase when only lowercase enabled"] = function()
  local opts = make_names_opts({ color_names_opts = { camelcase = false } })
  local hex = names.lookup_name("DeepSkyBlue", opts)
  eq(nil, hex)
end

T["lookup_name"]["returns nil for nil m_opts"] = function()
  local hex = names.lookup_name("red", nil)
  eq(nil, hex)
end

-- extra_word_chars -------------------------------------------------------------

T["extra_word_chars"] = new_set()

T["extra_word_chars"]["hyphen as word boundary prevents matching inside compound"] = function()
  local opts = make_names_opts({ extra_word_chars = "-" })
  -- "text-red-500": when hyphen is a word char, 'red' at position 6 is preceded by '-'
  -- which is now a word char, so it should NOT match
  local len = names.parser("text-red-500", 6, opts)
  eq(nil, len)
end

T["extra_word_chars"]["matches standalone name with hyphen boundaries"] = function()
  local opts = make_names_opts({ extra_word_chars = "-" })
  -- space-delimited: 'red' at position 1 should still match
  local len, hex = names.parser("red text", 1, opts)
  eq(3, len)
  eq("ff0000", hex)
end

T["extra_word_chars"]["default extra_word_chars includes hyphen"] = function()
  -- The default extra_word_chars is "-", so names at word start should still match
  local opts = make_names_opts()
  local len, hex = names.parser("red;", 1, opts)
  eq(3, len)
  eq("ff0000", hex)
end

return T
