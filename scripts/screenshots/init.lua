-- Screenshot init for nvim-colorizer.lua
-- Usage: COLORIZER_CONFIG=default nvim -u scripts/screenshots/init.lua -i NONE <fixture>

local script_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local config_name = vim.env.COLORIZER_CONFIG or "default"
dofile(script_dir .. "/configs.lua").screenshot_init(config_name)
