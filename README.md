# colorizer.lua

<!--toc:start-->

- [colorizer.lua](#colorizerlua)
  - [Installation and Usage](#installation-and-usage)
    - [Plugin managers](#plugin-managers)
    - [User commands](#user-commands)
    - [Lua API](#lua-api)
  - [Why another highlighter?](#why-another-highlighter)
    - [Neovim's built-in color highlighting](#neovims-built-in-color-highlighting)
  - [Configuration](#configuration)
    - [New structured options (recommended)](#new-structured-options-recommended)
    - [Legacy options (still supported)](#legacy-options-still-supported)
    - [Filetypes and buftypes](#filetypes-and-buftypes)
    - [Hooks](#hooks)
    - [Custom parsers](#custom-parsers)
    - [Tailwind](#tailwind)
  - [Testing](#testing)
  - [Documentation](#documentation)
  - [TODO](#todo)
  <!--toc:end-->

A high-performance color highlighter for Neovim which has **no external
dependencies**! Written in performant Luajit.

As long as you have `malloc()` and `free()` on your system, this will work.
Which includes Linux, OSX, and Windows.

![Demo.gif](https://github.com/catgoose/screenshots/blob/51466fa599efe6d9821715616106c1712aad00c3/nvim-colorizer.lua/demo-short.gif)

## Installation and Usage

Requires Neovim >= 0.10.0 and `set termguicolors` (enabled by default in 0.10+).

### Plugin managers

**Lazy.nvim:**

```lua
{
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    opts = {}, -- set to setup table
}
```

**Packer:**

```lua
use("catgoose/nvim-colorizer.lua")
```

**Manual:**

```lua
require("colorizer").setup()
```

### User commands

> [!NOTE]
> User commands can be enabled/disabled in setup opts

| Command                       | Description                                                 |
| ----------------------------- | ----------------------------------------------------------- |
| **ColorizerAttachToBuffer**   | Attach to the current buffer with given or default settings |
| **ColorizerDetachFromBuffer** | Stop highlighting the current buffer                        |
| **ColorizerReloadAllBuffers** | Reload all buffers that are being highlighted currently     |
| **ColorizerToggle**           | Toggle highlighting of the current buffer                   |

### Lua API

```lua
-- Attach with new format options
require("colorizer").attach_to_buffer(0, {
  parsers = { css = true },
  display = { mode = "foreground" },
})

-- Attach with legacy format options (still works)
require("colorizer").attach_to_buffer(0, { mode = "background", css = true })

-- Detach from buffer
require("colorizer").detach_from_buffer(0)
```

## Why another highlighter?

Mostly, **RAW SPEED**.

This has no external dependencies, which means you install it and **it just
works**. Other colorizers typically were synchronous and slow, as well. Being
written with performance in mind and leveraging the excellent LuaJIT and a
handwritten parser, updates can be done in real time. The downside
is that _this only works for Neovim_, and that will never change.

Apart from that, it only applies the highlights to the current visible contents,
so even if a big file is opened, the editor won't just choke on a blank screen.

Additionally, having a Lua API that's available means users can use this as a
library to do custom highlighting themselves.

### Neovim's built-in color highlighting

Neovim 0.10+ includes built-in treesitter-based syntax highlighting that can
colorize some color literals (e.g. color names in CSS files). This plugin
differs in several ways:

- **Format coverage:** Neovim's built-in highlighting is limited to what
  treesitter queries capture per language. This plugin supports hex (`#RGB`,
  `#RRGGBB`, `#RRGGBBAA`, `0xAARRGGBB`), CSS functions (`rgb()`, `hsl()`,
  `oklch()`), named colors, xterm/ANSI 256 colors, Tailwind CSS classes, Sass
  variables, and custom user-defined parsers — in any filetype.

- **Display modes:** Neovim only applies syntax highlight groups. This plugin
  offers background mode (with automatic contrast foreground text), foreground
  mode, and virtualtext mode (inline or end-of-line).

- **Priority handling:** Neovim's treesitter highlights run at extmark priority
  100. This plugin uses priority 200 (default) and 300 (Tailwind LSP) so
  colorizer highlights always take precedence. Without this, treesitter syntax
  colors (e.g. green for strings) would bleed through the colorizer background.

- **Performance:** The plugin uses a handwritten trie-based parser with
  byte-level dispatch, avoiding the overhead of treesitter queries for color
  detection. Only visible lines are processed.

## Configuration

Colorizer supports two configuration formats. The new **structured `options`**
format is recommended for new configs.  The legacy **`user_default_options`**
flat format continues to work and is translated internally.

### New structured options (recommended)

```lua
require("colorizer").setup({
  filetypes = { "*" },
  buftypes = {},
  user_commands = true,
  lazy_load = false,
  options = {
    parsers = {
      -- Presets: expand into individual parser enables, then are removed.
      -- Individual settings always override presets.
      css = false,       -- enables: names, hex, rgb, hsl, oklch
      css_fn = false,    -- enables: rgb, hsl, oklch

      names = {
        enable = false,  -- named colors (e.g. "Blue", "red")
        lowercase = true,
        camelcase = true,
        uppercase = false,
        strip_digits = false,
        custom = false,  -- table|function|false
      },

      hex = {
        enable = false,  -- master switch for all hex formats
        rgb = true,      -- #RGB
        rgba = true,     -- #RGBA
        rrggbb = true,   -- #RRGGBB
        rrggbbaa = false, -- #RRGGBBAA
        aarrggbb = false, -- 0xAARRGGBB
      },

      rgb = { enable = false },    -- rgb()/rgba()
      hsl = { enable = false },    -- hsl()/hsla()
      oklch = { enable = false },  -- oklch()

      tailwind = {
        enable = false,
        mode = "normal",       -- "normal"|"lsp"|"both"
        update_names = false,
      },

      sass = {
        enable = false,
        parsers = { css = true },
        variable_pattern = "^%$([%w_-]+)",  -- Lua pattern for sass variable names
      },

      xterm = { enable = false },

      -- Custom user parsers (see Custom parsers section)
      custom = {},
    },

    display = {
      mode = "background",       -- "background"|"foreground"|"virtualtext"
      background = {
        bright_fg = "#000000",   -- foreground text on bright backgrounds
        dark_fg = "#ffffff",     -- foreground text on dark backgrounds
      },
      virtualtext = {
        char = "■",
        position = false,        -- false|"before"|"after"
        hl_mode = "foreground",  -- "background"|"foreground"
      },
      priority = {
        default = 200,           -- extmark priority (> treesitter's 100)
        lsp = 300,               -- extmark priority for Tailwind LSP highlights
      },
    },

    hooks = {
      disable_line_highlight = false, -- function|false
    },

    always_update = false,
  },
})
```

**Quick examples:**

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

-- Preset with individual override: css enables everything, but disable rgb()
require("colorizer").setup({
  options = {
    parsers = { css = true, rgb = { enable = false } },
  },
})
```

### Legacy options (still supported)

The flat `user_default_options` format continues to work and is automatically
translated to the new format. A deprecation warning is shown once per session.

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

See the [full API documentation](https://catgoose.github.io/nvim-colorizer.lua/)
for the complete legacy option reference and translation mapping.

<details>
<summary>Legacy to new format translation table</summary>

| Legacy Key | New Key |
|---------|---------|
| `names` | `parsers.names.enable` |
| `names_opts.*` | `parsers.names.*` |
| `names_custom` | `parsers.names.custom` |
| `RGB` | `parsers.hex.rgb` + `parsers.hex.enable = true` |
| `RGBA` | `parsers.hex.rgba` + `parsers.hex.enable = true` |
| `RRGGBB` | `parsers.hex.rrggbb` + `parsers.hex.enable = true` |
| `RRGGBBAA` | `parsers.hex.rrggbbaa` + `parsers.hex.enable = true` |
| `AARRGGBB` | `parsers.hex.aarrggbb` + `parsers.hex.enable = true` |
| `rgb_fn` | `parsers.rgb.enable` |
| `hsl_fn` | `parsers.hsl.enable` |
| `oklch_fn` | `parsers.oklch.enable` |
| `css` | `parsers.css` (preset) |
| `css_fn` | `parsers.css_fn` (preset) |
| `tailwind = false` | `parsers.tailwind.enable = false` |
| `tailwind = true` | `parsers.tailwind = { enable = true, mode = "normal" }` |
| `tailwind = "lsp"` | `parsers.tailwind = { enable = true, mode = "lsp" }` |
| `tailwind_opts.update_names` | `parsers.tailwind.update_names` |
| `sass.enable` | `parsers.sass.enable` |
| `sass.parsers` | `parsers.sass.parsers` |
| `xterm` | `parsers.xterm.enable` |
| `mode` | `display.mode` |
| `virtualtext` | `display.virtualtext.char` |
| `virtualtext_inline = true` | `display.virtualtext.position = "after"` |
| `virtualtext_inline = "before"` | `display.virtualtext.position = "before"` |
| `virtualtext_mode` | `display.virtualtext.hl_mode` |
| `always_update` | `always_update` |
| `hooks.*` | `hooks.*` |

</details>

### Filetypes and buftypes

```lua
-- Highlight all files, exclude some, override others
require("colorizer").setup({
  filetypes = {
    "*",
    "!markdown",  -- exclude markdown
    html = { mode = "foreground" },  -- per-filetype override (legacy keys ok)
  },
})

-- Buftypes work the same way
require("colorizer").setup({
  buftypes = { "*", "!prompt", "!popup" },
})

-- Always update color values in unfocused buffers (e.g. cmp_docs)
require("colorizer").setup({
  filetypes = {
    "*",
    cmp_docs = { always_update = true },
  },
})

-- Lazyload with lazy.nvim
{
  "catgoose/nvim-colorizer.lua",
  event = "VeryLazy",
  opts = { lazy_load = true },
}
```

### Hooks

`disable_line_highlight` accepts a function called before each line is parsed:

```lua
---@param line string Line contents
---@param bufnr number Buffer number
---@param line_num number 0-indexed line number
---@return boolean true to skip highlighting this line
function(line, bufnr, line_num)
  return string.sub(line, 1, 2) == "--"
end
```

### Custom parsers

Register custom parsers to highlight application-specific color patterns:

```lua
require("colorizer").setup({
  options = {
    parsers = {
      custom = {
        {
          name = "android_color",
          prefixes = { "Color." },   -- trie prefixes for fast matching
          parse = function(ctx)
            local m = ctx.line:match(
              "^Color%.parseColor%(\"#(%x%x%x%x%x%x)\"%)", ctx.col
            )
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

Each custom parser definition supports:

| Field | Type | Description |
|-------|------|-------------|
| `name` | `string` | **Required.** Unique identifier |
| `parse` | `function(ctx)` | **Required.** Returns `(length, rgb_hex)` or `nil` |
| `prefixes` | `string[]` | Trie prefixes for fast dispatch (e.g. `{"Color."}`) |
| `prefix_bytes` | `number[]` | Raw byte triggers (e.g. `{0x23}` for `#`) |
| `setup` | `function(ctx)` | Called once on buffer attach |
| `teardown` | `function(ctx)` | Called on buffer detach |
| `state_factory` | `function()` | Returns initial per-buffer state table |

The `ctx` (ParserContext) passed to `parse`/`setup`/`teardown` contains:
`line`, `col`, `bufnr`, `line_nr`, `opts`, `parser_opts`, `state`.

### Tailwind

Tailwind colors can be parsed from the bundled color file
(`lua/colorizer/data/tailwind_colors.lua`) or via `textDocument/documentColor`
from the Tailwind LSP.

- `mode = "normal"` - parse standard Tailwind color names only
- `mode = "lsp"` - use Tailwind LSP document colors only
- `mode = "both"` - combine both sources

With `update_names = true` and `mode = "both"`, the color name mapping is
updated with LSP results including custom colors from `tailwind.config.{js,ts}`.

![tailwind.update_names](https://github.com/catgoose/screenshots/blob/51466fa599efe6d9821715616106c1712aad00c3/nvim-colorizer.lua/tailwind_update_names.png)

## Testing

```bash
make test               # Run all tests
make test-file FILE=f   # Run a single test file
make trie               # Run trie test and benchmark
make minimal            # Run minimal config
make minimal-tailwind       # Run minimal tailwind config (remote colorizer)
make minimal-tailwind-dev   # Run minimal tailwind config (local dev colorizer)
```

### Troubleshooting Tailwind

Minimal Tailwind configs are provided for debugging Tailwind CSS highlighting.
They bootstrap lazy.nvim, nvim-lspconfig, and a local `tailwindcss-language-server`
(installed via npm in `test/tailwind/`), then open `test/tailwind/tailwind.html`:

```bash
make minimal-tailwind       # uses remote colorizer (GitHub master)
make minimal-tailwind-dev   # uses local working copy
```

Dependencies (`tailwindcss` + `@tailwindcss/language-server`) are installed
automatically on first run via `npm install` in `test/tailwind/`.

Edit the `settings` table at the top of `test/minimal-tailwind.lua` to change:
- `tailwind_mode` - `"normal"`, `"lsp"`, or `"both"`

See the [Trie documentation](https://catgoose.github.io/nvim-colorizer.lua/modules/colorizer.trie.html)
for benchmark details.

## Documentation

- **Neovim help:** `:help colorizer` (generated via [lemmy-help](https://github.com/numToStr/lemmy-help))
- **Full API docs:** [catgoose.github.io/nvim-colorizer.lua](https://catgoose.github.io/nvim-colorizer.lua/)

## TODO

- [ ] Add more color types (var, advanced css functions)
- [ ] Add more display modes (e.g. sign column)
- [x] Support custom parsers
- [ ] Options support providing function to enable/disable instead of just boolean
