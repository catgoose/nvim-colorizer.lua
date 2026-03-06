# colorizer.lua

<!--toc:start-->

- [colorizer.lua](#colorizerlua)
  - [Why colorizer.lua?](#why-colorizerlua)
  - [Installation](#installation)
  - [Examples](#examples)
  - [Parser options](#parser-options)
    - [Hex `default` key](#hex-default-key)
  - [Default configuration](#default-configuration)
  - [Tailwind CSS](#tailwind-css)
    - [Neovim built-in LSP document colors (0.12+)](#neovim-built-in-lsp-document-colors-012)
  - [Highlight priority](#highlight-priority)
  - [Custom parsers](#custom-parsers)
  - [Hooks](#hooks)
  - [CSS custom properties](#css-custom-properties)
  - [Lua API](#lua-api)
  - [User commands](#user-commands)
  - [Legacy options](#legacy-options)
  - [Testing](#testing)
  - [Documentation](#documentation)
  <!--toc:end-->

> **[Full documentation](https://catgoose.github.io/nvim-colorizer.lua/)**

A high-performance color highlighter for Neovim with **no external
dependencies**. Written in performant Luajit.

![Demo](https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/demo.gif)

**[Screenshot tests](SCREENSHOT_TESTS.md)** — CI-generated visual tests for
every parser and display mode. If something looks off, click the `[N]` link
next to the test to report an issue.

## Why colorizer.lua?

- **Fast:** Handwritten trie-based parser with byte-level dispatch. Only visible lines are processed.
- **Zero dependencies:** As long as you have `malloc()` and `free()`, it works (Linux, macOS, Windows).
- **Broad format support:** Hex (`#RGB`, `#RRGGBB`, `#RRGGBBAA`, `#AARRGGBB` QML, `0xAARRGGBB`), CSS functions (`rgb()`, `hsl()`, `hwb()`, `lab()`, `lch()`, `oklch()`), CSS custom properties (`var(--name)`), named colors, xterm/ANSI 256, Tailwind CSS, Sass variables, and custom parsers — in any filetype.
- **Display modes:** Background (with auto-contrast text), foreground, and virtualtext (inline or end-of-line).
- **Higher priority than treesitter:** Uses `vim.hl.priorities` (diagnostics/user) so colorizer highlights always win over treesitter syntax colors.

## Installation

Requires Neovim >= 0.10.0 and `set termguicolors`

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

## Parser options

### Hex `default` key

The `default` key in `parsers.hex` sets the **default value** for all format
keys (`rgb`, `rgba`, `rrggbb`, `rrggbbaa`, `aarrggbb`). Any format key you
don't set explicitly inherits from `default`. Keys you set explicitly always
take priority.

```lua
-- Enable all hex formats
hex = { default = true }

-- Enable all hex formats except 8-digit (#RRGGBBAA)
hex = { default = true, rrggbbaa = false }

-- Disable all hex formats
hex = { default = false }

-- Only enable 6-digit hex
hex = { rrggbb = true }

-- Equivalent to the above (default is already false)
hex = { default = false, rrggbb = true }
```

> **Note:** Other parsers (`names`, `tailwind`, `sass`) use `enable` as a
> simple on/off switch. The `default` key is unique to `hex` because it is
> the only parser with multiple boolean format sub-keys.

## Default configuration

```lua
require("colorizer").setup({
  filetypes = { "*" }, -- filetypes to highlight, "*" for all
  buftypes = {}, -- buftypes to highlight
  user_commands = true, -- enable user commands (ColorizerToggle, etc.)
  lazy_load = false, -- lazily schedule buffer highlighting
  options = {
    parsers = {
      css = false, -- preset: enables names, hex, rgb, hsl, oklch, css_var
      css_fn = false, -- preset: enables rgb, hsl, oklch
      names = {
        enable = false, -- enable named colors (e.g. "Blue")
        lowercase = true, -- match lowercase names
        camelcase = true, -- match CamelCase names (e.g. "LightBlue")
        uppercase = false, -- match UPPERCASE names
        strip_digits = false, -- ignore names with trailing digits (e.g. "blue3")
        custom = false, -- custom name-to-hex mappings; table|function|false
      },
      hex = {
        default = false, -- default value for unset format keys (see above)
        rgb = false, -- #RGB (3-digit)
        rgba = false, -- #RGBA (4-digit)
        rrggbb = false, -- #RRGGBB (6-digit)
        rrggbbaa = false, -- #RRGGBBAA (8-digit)
        hash_aarrggbb = false, -- #AARRGGBB (QML-style, alpha first)
        aarrggbb = false, -- 0xAARRGGBB
        no_hash = false, -- hex without '#' at word boundaries
      },
      rgb = { enable = false }, -- rgb()/rgba() functions
      hsl = { enable = false }, -- hsl()/hsla() functions
      oklch = { enable = false }, -- oklch() function
      hwb = { enable = false }, -- hwb() function (CSS Color Level 4)
      lab = { enable = false }, -- lab() function (CIE Lab)
      lch = { enable = false }, -- lch() function (CIE LCH)
      tailwind = {
        enable = false, -- parse Tailwind color names
        update_names = false, -- feed LSP colors back into name parser (requires both enable + lsp.enable)
        lsp = { -- accepts boolean, true is shortcut for { enable = true, disable_document_color = true }
          enable = false, -- use Tailwind LSP documentColor
          disable_document_color = true, -- auto-disable vim.lsp.document_color on attach
        },
      },
      sass = {
        enable = false, -- parse Sass color variables
        parsers = { css = true }, -- parsers for resolving variable values
        variable_pattern = "^%$([%w_-]+)", -- Lua pattern for variable names
      },
      xterm = { enable = false }, -- xterm 256-color codes (#xNN, \e[38;5;NNNm)
      xcolor = { enable = false }, -- LaTeX xcolor expressions (e.g. red!30)
      hsluv = { enable = false }, -- hsluv()/hsluvu() functions
      css_var_rgb = { enable = false }, -- CSS vars with R,G,B (e.g. --color: 240,198,198)
      css_var = {
        enable = false, -- resolve var(--name) references to their defined color
        parsers = { css = true }, -- parsers for resolving variable values
      },
      custom = {}, -- list of custom parser definitions
    },
    display = {
      mode = "background", -- "background"|"foreground"|"virtualtext"
      background = {
        bright_fg = "#000000", -- text color on bright backgrounds
        dark_fg = "#ffffff", -- text color on dark backgrounds
      },
      virtualtext = {
        char = "■", -- character used for virtualtext
        position = "eol", -- "eol"|"before"|"after"
        hl_mode = "foreground", -- "background"|"foreground"
      },
      priority = {
        default = 150, -- extmark priority for normal highlights
        lsp = 200, -- extmark priority for LSP/Tailwind highlights
      },
    },
    hooks = {
      should_highlight_line = false, -- function(line, bufnr, line_num) -> bool
    },
    always_update = false, -- update highlights even in unfocused buffers
    debounce_ms = 0, -- debounce highlight updates (ms); 0 = no debounce
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

`lsp` accepts a boolean shorthand or a table for fine-grained control:

```lua
require("colorizer").setup({
  options = {
    parsers = {
      tailwind = { enable = true, lsp = true },
    },
  },
})
```

```lua
require("colorizer").setup({
  options = {
    parsers = {
      tailwind = {
        enable = true,
        lsp = {
          enable = true,
          disable_document_color = true, -- default
        },
        update_names = true,
      },
    },
  },
})
```

With `lsp.update_names = true` and both `enable` + `lsp.enable` active, LSP
results are fed back into the name parser's color table. Name-based parsing is
instant (works in cmp windows, new buffers, etc.) but uses bundled color data.
The LSP is slower (requires server response) but reads custom colors from
`tailwind.config.{js,ts}`. By combining both, buffers are painted immediately
with name-based matches, then LSP results correct the colors and update the
name table so subsequent name-based highlights use accurate values.

![tailwind.update_names](https://github.com/catgoose/screenshots/blob/51466fa599efe6d9821715616106c1712aad00c3/nvim-colorizer.lua/tailwind_update_names.png)

### Neovim built-in LSP document colors (0.12+)

Neovim 0.12+ has built-in `textDocument/documentColor` support via
`vim.lsp.document_color` that is **enabled by default** on `LspAttach`. When
colorizer's `tailwind.lsp` is active, `disable_document_color` (default `true`)
automatically calls `vim.lsp.document_color.enable(false, bufnr)` to prevent
duplicate highlights. No manual `LspAttach` autocmd is needed.

To **keep the built-in feature active** alongside colorizer:

```lua
tailwind = {
  enable = true,
  lsp = { enable = true, disable_document_color = false },
},
```

**Or use the built-in feature instead** and disable colorizer's LSP integration:

```lua
-- Let Neovim handle LSP colors, colorizer handles everything else
require("colorizer").setup({
  options = {
    parsers = {
      tailwind = { enable = true, lsp = false },
    },
  },
})
```

The built-in `vim.lsp.document_color.enable()` supports style options:
`'background'` (default), `'foreground'`, `'virtual'`, or a custom string/function.
See `:help vim.lsp.document_color.enable()` for details.

> **Note:** This only applies to Neovim 0.12+. Neovim 0.10 and 0.11 do not
> have this feature and are unaffected.

## Highlight priority

Colorizer uses extmark priorities from `display.priority` to control which
highlights win when multiple sources target the same range:

| Key       | Default | Based on                        | Purpose                        |
| --------- | ------- | ------------------------------- | ------------------------------ |
| `default` | 150     | `vim.hl.priorities.diagnostics` | Normal parser-based highlights |
| `lsp`     | 200     | `vim.hl.priorities.user`        | Tailwind LSP highlights        |

These defaults are higher than treesitter (100) and semantic tokens (125), so
colorizer highlights always win over syntax highlighting. The LSP priority is
higher than default so Tailwind LSP results take precedence over parser-based
matches on the same range.

Neovim's built-in `vim.lsp.document_color` sets **no explicit priority** on its
extmarks (effectively 0), so if both are active on the same buffer you get
duplicate highlights rather than a priority conflict. This is why
`disable_document_color` defaults to `true` — it prevents the duplicates
entirely.

To customize priorities:

```lua
require("colorizer").setup({
  options = {
    display = {
      priority = {
        default = 50, -- lower than treesitter, color highlights lose
        lsp = 300, -- higher than default user priority
      },
    },
  },
})
```

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

## CSS custom properties

The `css_var` parser resolves `var(--name)` references by scanning the buffer
for `--name: <color>` definitions. Any color format recognized by the configured
parsers (hex, rgb, hsl, etc.) works in definitions.

```lua
require("colorizer").setup({
  options = {
    parsers = {
      css = true, -- also enables css_var via the css preset
    },
  },
})
```

Or enable it explicitly without the full css preset:

```lua
require("colorizer").setup({
  options = {
    parsers = {
      hex = { default = true },
      css_var = { enable = true, parsers = { css = true } },
    },
  },
})
```

Features:

- Resolves aliased variables: `--alias: var(--base)` chains are followed
- Handles `var(--name, fallback)` syntax (highlights using the definition)
- Re-scans definitions on every text change

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

The flat `user_default_options` format is fully supported and automatically
translated to the new structured format internally. No migration is required.

**Important:**

- The legacy option set is **frozen** — no new options will be added to it.
  New features (e.g. `hsluv`, `xcolor`, `css_var_rgb`, `css_var`,
  `debounce_ms`, `hex.hash_aarrggbb`, `hex.no_hash`) are
  only available via the structured `options` format.
- If both `options` and `user_default_options` are provided, `options` wins.

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

See `:help colorizer.config` and the
[full documentation](https://catgoose.github.io/nvim-colorizer.lua/) for the
legacy-to-new translation mapping.

## Testing

```bash
make test
make test-file FILE=tests/test_config.lua
```

## Documentation

- `:help colorizer`
- [Full API docs](https://catgoose.github.io/nvim-colorizer.lua/)
