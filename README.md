# colorizer.lua

<!--toc:start-->

- [colorizer.lua](#colorizerlua)
  - [Why colorizer.lua?](#why-colorizerlua)
  - [Installation](#installation)
  - [Examples](#examples)
  - [Default configuration](#default-configuration)
  - [Tailwind CSS](#tailwind-css)
  - [Custom parsers](#custom-parsers)
  - [Hooks](#hooks)
  - [Lua API](#lua-api)
  - [User commands](#user-commands)
  - [Legacy options](#legacy-options)
  - [Testing](#testing)
  - [Documentation](#documentation)
  <!--toc:end-->

> **[Full documentation](https://catgoose.github.io/nvim-colorizer.lua/)**

A high-performance color highlighter for Neovim with **no external
dependencies**. Written in performant Luajit.

![Demo.gif](https://github.com/catgoose/screenshots/blob/51466fa599efe6d9821715616106c1712aad00c3/nvim-colorizer.lua/demo-short.gif)

## Why colorizer.lua?

- **Fast:** Handwritten trie-based parser with byte-level dispatch. Only visible lines are processed.
- **Zero dependencies:** As long as you have `malloc()` and `free()`, it works (Linux, macOS, Windows).
- **Broad format support:** Hex (`#RGB`, `#RRGGBB`, `#RRGGBBAA`, `0xAARRGGBB`), CSS functions (`rgb()`, `hsl()`, `oklch()`), named colors, xterm/ANSI 256, Tailwind CSS, Sass variables, and custom parsers — in any filetype.
- **Display modes:** Background (with auto-contrast text), foreground, and virtualtext (inline or end-of-line).
- **Higher priority than treesitter:** Uses extmark priority 200/300 so colorizer highlights always win over treesitter syntax colors.

## Installation

Requires Neovim >= 0.10.0

```lua
-- lazy.nvim
{
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    opts = {},
}
```

## Examples

```lua
-- Enable all CSS color formats
require("colorizer").setup({
  options = { parsers = { css = true } },
})

-- CSS functions only, with virtualtext display
require("colorizer").setup({
  options = {
    parsers = { css_fn = true },
    display = {
      mode = "virtualtext",
      virtualtext = { position = "after" },
    },
  },
})

-- Preset with individual override
require("colorizer").setup({
  options = {
    parsers = { css = true, rgb = { enable = false } },
  },
})

-- Per-filetype overrides
require("colorizer").setup({
  filetypes = {
    "*",
    "!markdown",
    html = { mode = "foreground" },
    cmp_docs = { always_update = true },
  },
})
```

## Default configuration

```lua
require("colorizer").setup({
  filetypes = { "*" },
  buftypes = {},
  user_commands = true,
  lazy_load = false,
  options = {
    parsers = {
      css = false, -- preset: enables names, hex, rgb, hsl, oklch
      css_fn = false, -- preset: enables rgb, hsl, oklch
      names = {
        enable = false,
        lowercase = true,
        camelcase = true,
        uppercase = false,
        strip_digits = false,
        custom = false, -- table|function|false
      },
      hex = {
        enable = false, -- master switch for all hex formats
        rgb = true, -- #RGB
        rgba = true, -- #RGBA
        rrggbb = true, -- #RRGGBB
        rrggbbaa = false, -- #RRGGBBAA
        aarrggbb = false, -- 0xAARRGGBB
      },
      rgb = { enable = false },
      hsl = { enable = false },
      oklch = { enable = false },
      tailwind = {
        enable = false, -- parse Tailwind color names
        lsp = false, -- use Tailwind LSP documentColor
        update_names = false,
      },
      sass = {
        enable = false,
        parsers = { css = true },
        variable_pattern = "^%$([%w_-]+)",
      },
      xterm = { enable = false },
      custom = {},
    },
    display = {
      mode = "background", -- "background"|"foreground"|"virtualtext"
      background = {
        bright_fg = "#000000",
        dark_fg = "#ffffff",
      },
      virtualtext = {
        char = "■",
        position = "eol", -- "eol"|"before"|"after"
        hl_mode = "foreground",
      },
      priority = {
        default = 200,
        lsp = 300,
      },
    },
    hooks = {
      should_highlight_line = false, -- function(line, bufnr, line_num) -> bool
    },
    always_update = false,
  },
})
```

## Tailwind CSS

Tailwind colors can be parsed from the bundled color data (`enable`) or via `textDocument/documentColor` from the Tailwind LSP (`lsp`). Both can be used together.

| Option          | Behavior                            |
| --------------- | ----------------------------------- |
| `enable = true` | Parse standard Tailwind color names |
| `lsp = true`    | Use Tailwind LSP document colors    |
| Both `true`     | Combine both sources                |

With `update_names = true` and both enabled, the color name mapping is updated with LSP results including custom colors from `tailwind.config.{js,ts}`.

```lua
require("colorizer").setup({
  options = {
    parsers = {
      tailwind = { enable = true, lsp = true, update_names = true },
    },
  },
})
```

![tailwind.update_names](https://github.com/catgoose/screenshots/blob/51466fa599efe6d9821715616106c1712aad00c3/nvim-colorizer.lua/tailwind_update_names.png)

## Custom parsers

Register custom parsers to highlight application-specific color patterns:

```lua
require("colorizer").setup({
  options = {
    parsers = {
      custom = {
        {
          name = "android_color",
          prefixes = { "Color." },
          parse = function(ctx)
            local m = ctx.line:match('^Color%.parseColor%("#(%x%x%x%x%x%x)"%)', ctx.col)
            if m then
              return #'Color.parseColor("#xxxxxx")', m:lower()
            end
          end,
        },
      },
    },
  },
})
```

Each custom parser supports: `name`, `parse(ctx)`, `prefixes`, `prefix_bytes`, `setup(ctx)`, `teardown(ctx)`, `state_factory()`. See the [full documentation](https://catgoose.github.io/nvim-colorizer.lua/) for details.

## Hooks

`should_highlight_line` is called before each line is parsed. Return `true` to highlight, `false` to skip:

```lua
require("colorizer").setup({
  options = {
    hooks = {
      should_highlight_line = function(line, bufnr, line_num)
        return string.sub(line, 1, 2) ~= "--"
      end,
    },
  },
})
```

## Lua API

```lua
require("colorizer").attach_to_buffer(0, {
  parsers = { css = true },
  display = { mode = "foreground" },
})
require("colorizer").detach_from_buffer(0)
```

## User commands

| Command                       | Description                               |
| ----------------------------- | ----------------------------------------- |
| **ColorizerAttachToBuffer**   | Attach to the current buffer              |
| **ColorizerDetachFromBuffer** | Stop highlighting the current buffer      |
| **ColorizerReloadAllBuffers** | Reload all highlighted buffers            |
| **ColorizerToggle**           | Toggle highlighting of the current buffer |

## Legacy options

The flat `user_default_options` format continues to work and is translated
internally. A deprecation warning is shown once per session.

```lua
require("colorizer").setup({
  user_default_options = {
    names = true,
    RGB = true,
    RRGGBB = true,
    css = false,
    mode = "background",
    tailwind = false,
  },
})
```

See the [full documentation](https://catgoose.github.io/nvim-colorizer.lua/) for the legacy-to-new translation mapping.

## Testing

```bash
make test
make test-file FILE=tests/test_config.lua
```

## Documentation

- `:help colorizer`
- [Full API docs](https://catgoose.github.io/nvim-colorizer.lua/)
