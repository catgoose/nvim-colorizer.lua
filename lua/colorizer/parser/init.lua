---@mod colorizer.parser Parser Loader
---@brief [[
---Loads all built-in parsers and returns the registry.
---Each parser module registers itself via `registry.register()` on require.
---@brief ]]

local registry = require("colorizer.parser.registry")

-- Load each parser module; side-effect: each calls registry.register(M.spec)
require("colorizer.parser.rgba_hex")
require("colorizer.parser.argb_hex")
require("colorizer.parser.xterm")
require("colorizer.parser.rgb")
require("colorizer.parser.hsl")
require("colorizer.parser.oklch")
require("colorizer.parser.names")
require("colorizer.parser.sass")

return registry
