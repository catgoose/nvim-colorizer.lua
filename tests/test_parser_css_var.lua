local helpers = require("tests.helpers")
local eq = helpers.eq
local new_set = helpers.new_set

local css_var = require("colorizer.parser.css_var")

local T = new_set()

-- Helper: simple color parser that recognizes #RRGGBB and named colors
local function color_parser(line, i)
  local sub = line:sub(i)
  -- #RRGGBB
  local hex = sub:match("^#(%x%x%x%x%x%x)")
  if hex then
    return 7, hex:lower()
  end
  -- #RGB
  local short = sub:match("^#(%x)(%x)(%x)")
  if short then
    local r, g, b = sub:match("^#(%x)(%x)(%x)")
    return 4, (r .. r .. g .. g .. b .. b):lower()
  end
  -- rgb(r,g,b)
  local r, g, b = sub:match("^rgb%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)")
  if r then
    local full = sub:match("^rgb%(%d+%s*,%s*%d+%s*,%s*%d+%s*%)")
    return #full, string.format("%02x%02x%02x", tonumber(r), tonumber(g), tonumber(b))
  end
  return nil
end

-- Helpers for stateful tests
local function make_buf()
  return vim.api.nvim_create_buf(false, true)
end

local function setup_vars(bufnr, lines)
  css_var.update_variables(bufnr, 0, #lines, lines, color_parser)
end

-- Basic reference resolution ------------------------------------------------

T["reference"] = new_set()

T["reference"]["resolves var(--color) with hex definition"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --primary: #ff0000;" })
  local len, hex = css_var.parser("color: var(--primary)", 8, bufnr)
  eq(14, len)
  eq("ff0000", hex)
  css_var.cleanup(bufnr)
end

T["reference"]["resolves var(--color) with rgb definition"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --accent: rgb(0,255,0);" })
  local len, hex = css_var.parser("background: var(--accent)", 13, bufnr)
  eq(13, len)
  eq("00ff00", hex)
  css_var.cleanup(bufnr)
end

T["reference"]["resolves var(--color) with short hex"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --short: #f00;" })
  local len, hex = css_var.parser("color: var(--short)", 8, bufnr)
  eq(12, len)
  eq("ff0000", hex)
  css_var.cleanup(bufnr)
end

T["reference"]["returns nil for undefined variable"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --primary: #ff0000;" })
  local len = css_var.parser("color: var(--unknown)", 8, bufnr)
  eq(nil, len)
  css_var.cleanup(bufnr)
end

T["reference"]["returns nil for non-color variable"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --spacing: 1rem;" })
  local len = css_var.parser("margin: var(--spacing)", 9, bufnr)
  eq(nil, len)
  css_var.cleanup(bufnr)
end

T["reference"]["returns nil without state"] = function()
  local bufnr = make_buf()
  local len = css_var.parser("color: var(--primary)", 8, bufnr)
  eq(nil, len)
end

-- Recursive variable resolution ---------------------------------------------

T["recursive"] = new_set()

T["recursive"]["resolves var(--alias) -> var(--base)"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, {
    "  --base-color: #0000ff;",
    "  --alias: var(--base-color);",
  })
  local len, hex = css_var.parser("color: var(--alias)", 8, bufnr)
  eq(12, len)
  eq("0000ff", hex)
  css_var.cleanup(bufnr)
end

T["recursive"]["handles circular references gracefully"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, {
    "  --a: var(--b);",
    "  --b: var(--a);",
  })
  local len = css_var.parser("color: var(--a)", 8, bufnr)
  eq(nil, len)
  css_var.cleanup(bufnr)
end

-- Multiple definitions ------------------------------------------------------

T["multiple"] = new_set()

T["multiple"]["tracks multiple definitions"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, {
    "  --red: #ff0000;",
    "  --green: #00ff00;",
    "  --blue: #0000ff;",
  })
  local _, hex1 = css_var.parser("var(--red)", 1, bufnr)
  local _, hex2 = css_var.parser("var(--green)", 1, bufnr)
  local _, hex3 = css_var.parser("var(--blue)", 1, bufnr)
  eq("ff0000", hex1)
  eq("00ff00", hex2)
  eq("0000ff", hex3)
  css_var.cleanup(bufnr)
end

-- Definition patterns -------------------------------------------------------

T["definitions"] = new_set()

T["definitions"]["handles !important"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --color: #ff0000 !important;" })
  local _, hex = css_var.parser("var(--color)", 1, bufnr)
  eq("ff0000", hex)
  css_var.cleanup(bufnr)
end

T["definitions"]["handles indented definitions"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "    --deep-indent: #abcdef;" })
  local _, hex = css_var.parser("var(--deep-indent)", 1, bufnr)
  eq("abcdef", hex)
  css_var.cleanup(bufnr)
end

T["definitions"]["handles definition without semicolon at EOL"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --no-semi: #123456" })
  local _, hex = css_var.parser("var(--no-semi)", 1, bufnr)
  eq("123456", hex)
  css_var.cleanup(bufnr)
end

-- Cleanup -------------------------------------------------------------------

T["cleanup"] = new_set()

T["cleanup"]["cleanup removes state"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --color: #ff0000;" })
  css_var.cleanup(bufnr)
  local len = css_var.parser("var(--color)", 1, bufnr)
  eq(nil, len)
end

T["cleanup"]["cleanup on non-existent buffer is safe"] = function()
  css_var.cleanup(99999)
end

-- var() with spaces ---------------------------------------------------------

T["spacing"] = new_set()

T["spacing"]["handles spaces inside var()"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --color: #ff0000;" })
  local len, hex = css_var.parser("var( --color )", 1, bufnr)
  eq(14, len)
  eq("ff0000", hex)
  css_var.cleanup(bufnr)
end

-- var() with fallback (comma) -----------------------------------------------

T["fallback"] = new_set()

T["fallback"]["parses var with fallback but uses definition"] = function()
  local bufnr = make_buf()
  setup_vars(bufnr, { "  --color: #ff0000;" })
  -- var(--color, #00ff00) - the fallback is ignored, definition is used
  -- Our pattern matches up to the first , or )
  local _, hex = css_var.parser("var(--color, #00ff00)", 1, bufnr)
  eq("ff0000", hex)
  css_var.cleanup(bufnr)
end

return T
