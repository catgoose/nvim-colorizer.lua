# colorizer.lua

<!--toc:start-->

- [colorizer.lua](#colorizerlua)
  - [Installation and Usage](#installation-and-usage)
    - [Plugin managers](#plugin-managers)
      - [Lazy.nvim](#lazynvim)
      - [Packer](#packer)
      - [Manual](#manual)
    - [User commands](#user-commands)
    - [Lua API](#lua-api)
  - [Why another highlighter?](#why-another-highlighter)
  - [Customization](#customization)
    - [Hooks](#hooks)
    - [Setup Examples](#setup-examples)
    - [Updating color even when buffer is not focused](#updating-color-even-when-buffer-is-not-focused)
    - [Lazyload Colorizer with Lazy.nvim](#lazyload-colorizer-with-lazynvim)
    - [Tailwind](#tailwind)
  - [Testing](#testing)
    - [Minimal Colorizer](#minimal-colorizer)
    - [Trie](#trie)
      - [Test](#test)
      - [Benchmark](#benchmark)
  - [Extras](#extras)
  - [TODO](#todo)
  <!--toc:end-->

[![luadoc](https://img.shields.io/badge/luadoc-0.1-blue)](https://catgoose.github.io/nvim-colorizer.lua/)

A high-performance color highlighter for Neovim which has **no external
dependencies**! Written in performant Luajit.

As long as you have `malloc()` and `free()` on your system, this will work.
Which includes Linux, OSX, and Windows.

![Demo.gif](https://github.com/catgoose/screenshots/blob/51466fa599efe6d9821715616106c1712aad00c3/nvim-colorizer.lua/demo-short.gif)

## Installation and Usage

Requires Neovim >= 0.7.0 and `set termguicolors`.

### Plugin managers

#### Lazy.nvim

```lua
{
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    opts = { -- set to setup table
    },
}
```

#### Packer

```lua
use("catgoose/nvim-colorizer.lua")
```

#### Manual

> [!NOTE]
> You should add this line after/below where your plugins are setup.

```lua
require("colorizer").setup()
```

This will create an `autocmd` for `FileType *` to highlight
every filetype.

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
-- All options that can be passed to `user_default_options` in setup() can be
-- passed to `attach_to_buffer`
-- Similar for other functions

-- Attach to buffer
require("colorizer").attach_to_buffer(0, { mode = "background", css = true })

-- Detach from buffer
require("colorizer").detach_from_buffer(0, { mode = "virtualtext", css = true })
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

## Customization

> [!NOTE]
> These are the default options

```lua
  require("colorizer").setup({
    filetypes = { "*" }, -- Filetype options.  Accepts table like `user_default_options`
    buftypes = {}, -- Buftype options.  Accepts table like `user_default_options`
    -- Boolean | List of usercommands to enable.  See User commands section.
    user_commands = true, -- Enable all or some usercommands
    lazy_load = false, -- Lazily schedule buffer highlighting setup function
    user_default_options = {
      names = true, -- "Name" codes like Blue or red.  Added from `vim.api.nvim_get_color_map()`
      names_opts = { -- options for mutating/filtering names.
        lowercase = true, -- name:lower(), highlight `blue` and `red`
        camelcase = true, -- name, highlight `Blue` and `Red`
        uppercase = false, -- name:upper(), highlight `BLUE` and `RED`
        strip_digits = false, -- ignore names with digits,
        -- highlight `blue` and `red`, but not `blue3` and `red4`
      },
      -- Expects a table of color name to #RRGGBB value pairs.  # is optional
      -- Example: { cool = "#107dac", ["notcool"] = "ee9240" }
      -- Set to false to disable, for example when setting filetype options
      names_custom = false, -- Custom names to be highlighted: table|function|false
      RGB = true, -- #RGB hex codes
      RGBA = true, -- #RGBA hex codes
      RRGGBB = true, -- #RRGGBB hex codes
      RRGGBBAA = false, -- #RRGGBBAA hex codes
      AARRGGBB = false, -- 0xAARRGGBB hex codes
      rgb_fn = false, -- CSS rgb() and rgba() functions
      hsl_fn = false, -- CSS hsl() and hsla() functions
      css = false, -- Enable all CSS *features*:
      -- names, RGB, RGBA, RRGGBB, RRGGBBAA, AARRGGBB, rgb_fn, hsl_fn
      css_fn = false, -- Enable all CSS *functions*: rgb_fn, hsl_fn
      -- Tailwind colors.  boolean|'normal'|'lsp'|'both'.  True sets to 'normal'
      tailwind = false, -- Enable tailwind colors
      tailwind_opts = { -- Options for highlighting tailwind names
        update_names = false, -- When using tailwind = 'both', update tailwind names from LSP results.  See tailwind section
      },
      -- parsers can contain values used in `user_default_options`
      sass = { enable = false, parsers = { "css" } }, -- Enable sass colors
      -- Highlighting mode.  'background'|'foreground'|'virtualtext'
      mode = "background", -- Set the display mode
      -- Virtualtext character to use
      virtualtext = "■",
      -- Display virtualtext inline with color.  boolean|'before'|'after'.  True sets to 'after'
      virtualtext_inline = false,
      -- Virtualtext highlight mode: 'background'|'foreground'
      virtualtext_mode = "foreground",
      -- update color values even if buffer is not focused
      -- example use: cmp_menu, cmp_docs
      always_update = false,
      -- hooks to invert control of colorizer
      hooks = {
        -- called before line parsing.  Accepts boolean or function that returns boolean
        -- see hooks section below
        disable_line_highlight = false,
      },
    },
  })
```

### Hooks

Hooks into colorizer can be defined to customize colorization behavior.

`disable_line_highlight`: Expects a function that returns a boolean. The function is called before line parsing with the following function signature:

```lua
---@param line string: Line's contents
---@param bufnr number: Buffer number
---@line_num number: Line number (0-indexed).  Add 1 to get the line number in buffer
---@return boolean: Return true if current line should be parsed for highlighting.
function(line, bufnr, line_num)
  -- Treesitter could also be used, but be warned it will be quite laggy unless you are caching results somehow
  return string.sub(line, 1, 2) ~= "--"
end
```

### Setup Examples

```lua
-- Attaches to every FileType with default options
require("colorizer").setup()

-- Attach to certain Filetypes, add special `mode` configuration for `html`
-- Use `background` for everything else.
require("colorizer").setup({
  filetypes = {
    "css",
    "javascript",
    html = { mode = "foreground" },
  },
})

-- Use `user_default_options` as the second parameter, which uses
-- `background` for every mode. This is the inverse of the previous
-- setup configuration.
require("colorizer").setup({
  filetypes = {
    "css",
    "javascript",
    html = { mode = "foreground" },
  },
  user_default_options = { mode = "background" },
})

-- Use default for all filetypes with overrides for css and html
require("colorizer").setup({
  filetypes = {
    "*", -- Highlight all files, but customize some others.
    css = { rgb_fn = true }, -- Enable parsing rgb(...) functions in css.
    html = { names = false }, -- Disable parsing "names" like Blue or Gray
  },
})

-- Exclude some filetypes from highlighting by using `!`
require("colorizer").setup({
  filetypes = {
    "*", -- Highlight all files, but customize some others.
    "!vim", -- Exclude vim from highlighting.
    -- Exclusion Only makes sense if '*' is specified first!
  },
})

-- Always update the color values in cmp_docs even if it not focused
require("colorizer").setup({
  filetypes = {
    "*", -- Highlight all files, but customize some others.
    cmp_docs = { always_update = true },
  },
})

-- Only enable ColorizerToggle and ColorizerReloadAllBuffers user_command
require("colorizer").setup({
  user_commands = { "ColorizerToggle", "ColorizerReloadAllBuffers" },
})

-- Apply names_custom from theme
-- names_custom are stored by hashed key to allow filetype to override `user_default_options`
require("colorizer").setup({
  names = true,
  names_custom = function()
    local colors = require("kanagawa.colors").setup({ theme = "dragon" })
    return colors.palette
  end,
  filetypes = {
    "*",
    lua = { -- use different theme for lua filetype
      names_custom = function()
        local colors = require("kanagawa.colors").setup({ theme = "wave" })
        return colors.palette
      end,
    },
  },
})
```

In `user_default_options`, there are 2 types of options

1. Individual options - `names`, `names_opts`, `names_custom`, `RGB`, `RGBA`,
   `RRGGBB`, `RRGGBBAA`, `hsl_fn`, `rgb_fn`, `RRGGBBAA`, `AARRGGBB`, `tailwind`,
   `sass`

1. Alias options - `css`, `css_fn`

If `css_fn` is true `hsl_fn`, `rgb_fn` becomes `true`

If `css` is true `names`, `RGB`, `RGBA`, `RRGGBB`, `RRGGBBAA`, `hsl_fn`, `rgb_fn`
becomes `true`

These options have a priority, Individual options have the highest priority,
then alias options

For alias, `css_fn` has more priority over `css`

e.g: Here `RGB`, `RGBA`, `RRGGBB`, `RRGGBBAA`, `AARRGGBB`, `hsl_fn`, `rgb_fn` is
enabled but not `names`

```lua
require("colorizer").setup({
  user_default_options = {
    names = false,
    css = true,
  },
})
```

e.g: Here `names`, `RGB`, `RGBA`, `RRGGBB`, `RRGGBBAA`, `AARRGGBB` is enabled but
not `rgb_fn` and `hsl_fn`

```lua
require("colorizer").setup({
  user_default_options = {
    css_fn = false,
    css = true,
  },
})
```

### Updating color even when buffer is not focused

Like in floating windows, popup menu, etc

use `always_update` flag. Use with caution, as this will update for any change
in that buffer, whether focused or not.

```lua
-- Alwyas update the color values in cmp_docs even if it not focused
require("colorizer").setup({
  filetypes = {
    "*", -- Highlight all files, but customize some others.
    cmp_docs = { always_update = true },
  },
})
```

All the above examples can also be apply to buftypes. Also no buftypes trigger
colorizer by default

Buftype value is fetched by `vim.bo.buftype`

```lua
-- need to specify buftypes
require("colorizer").setup(
  buftypes = {
      "*",
      -- exclude prompt and popup buftypes from highlight
      "!prompt",
      "!popup",
    }
)
```

For lower level interface, see
[LuaDocs for API details](https://catgoose.github.io/nvim-colorizer.lua/modules/colorizer.html)
or use `:h colorizer` once installed.

### Lazyload Colorizer with Lazy.nvim

```lua
return {
  "catgoose/nvim-colorizer.lua",
  event = "VeryLazy",
  opts = {
    lazy_load = true,
    -- other setup options
  },
}
```

### Tailwind

Tailwind colors can either be parsed from the Tailwind colors file (found in
`lua/colorizer/data/tailwind_colors.lua`) or by requesting
`textDocument/documentColor` from the LSP.

When using `tailwind="normal"`, only standard color names/values are parsed.

Using the `tailwind_opts.update_names` configuration option, the `tailwind_names`
color mapping will be updated with results from Tailwind LSP, including custom
colors defined in `tailwind.config.{js,ts}`.

This can be useful if you are highlighting `cmp_menu` filetype.

```typescript
// tailwind.config.ts
    extend: {
      colors: {
        gray: {
          600: '#2CEF6F',
          700: '#AC50EF',
          800: '#2ECFF6',
        },
      },
    },
```

![tailwind.update_names](https://github.com/catgoose/screenshots/blob/51466fa599efe6d9821715616106c1712aad00c3/nvim-colorizer.lua/tailwind_update_names.png)
To improve highlighting performance with the slow Tailwind LSP, results from LSP
are cached and returned on `WinScrolled` event.

## Testing

### Minimal Colorizer

For troubleshooting use `test/minimal-colorizer.lua`.
Startup neovim with `nvim --clean -u minimal-colorizer.lua` in the `test` directory.

Alternatively,

```bash
make minimal
```

or

```bash
scripts/minimal-colorizer.sh
```

To test colorization with your config, edit `test/expect.lua` to see expected
highlights.
The returned table of `user_default_options` from `text/expect.lua` will be used
to conveniently reattach Colorizer to `test/expect.lua` on save.

### Trie

Colorizer uses a space efficient LuaJIT Trie implementation, which starts with
an initial node capacity of 8 bytes and expands capacity per node when needed.

The trie can be tested and benchmarked using `test/trie/test.lua` and
`test/trie/benchmark.lua` respectively.

#### Test

```bash
# runs both trie-test and trie-benchmark targets
make trie
```

```bash
# runs trie test which inserts words and checks longest prefix
make trie-test
```

#### Benchmark

```bash
scripts/trie-test.sh
```

```bash
# runs benchmark for different node initial capacity allocation
make trie-benchmark
```

```bash
scripts/trie-benchmark.sh
```

Inserting 7245 words: using uppercase, lowercase, camelcase from `vim.api.nvim_get_color_map()` and Tailwind colors

| Initial Capacity | Resize Count | Insert Time (ms) | Lookup Time (ms) |
| ---------------- | ------------ | ---------------- | ---------------- |
| 1                | 3652         | 25               | 16               |
| 2                | 2056         | 11               | 8                |
| 4                | 1174         | 6                | 5                |
| 8                | 576          | 7                | 5                |
| 16               | 23           | 7                | 5                |
| 32               | 1            | 8                | 6                |
| 64               | 0            | 10               | 7                |

Inserting 1000 randomized words

| Initial Capacity | Resize Count | Insert Time (ms) | Lookup Time (ms) |
| ---------------- | ------------ | ---------------- | ---------------- |
| 1                | 434          | 1                | 0                |
| 2                | 234          | 1                | 1                |
| 4                | 129          | 1                | 0                |
| 8                | 51           | 1                | 0                |
| 16               | 17           | 1                | 1                |
| 32               | 3            | 1                | 2                |
| 64               | 1            | 2                | 1                |
| 128              | 0            | 4                | 1                |

Inserting 10,000 randomized words

| Initial Capacity | Resize Count | Insert Time (ms) | Lookup Time (ms) |
| ---------------- | ------------ | ---------------- | ---------------- |
| 1                | 4614         | 9                | 7                |
| 2                | 2106         | 8                | 8                |
| 4                | 842          | 9                | 7                |
| 8                | 362          | 9                | 8                |
| 16               | 208          | 11               | 9                |
| 32               | 113          | 14               | 11               |
| 64               | 24           | 21               | 14               |
| 128              | 0            | 34               | 25               |

Inserting 100,000 randomized words

| Initial Capacity | Resize Count | Insert Time (ms) | Lookup Time (ms) |
| ---------------- | ------------ | ---------------- | ---------------- |
| 1                | 40656        | 160              | 117              |
| 2                | 21367        | 116              | 111              |
| 4                | 11604        | 122              | 109              |
| 8                | 5549         | 133              | 113              |
| 16               | 1954         | 141              | 138              |
| 32               | 499          | 173              | 158              |
| 64               | 100          | 233              | 173              |
| 128              | 0            | 343              | 198              |

## Extras

Documentation is generated using ldoc. See
[scripts/gen_docs.sh](https://github.com/colorizer/nvim-colorizer.lua/blob/master/scripts/gen_docs.sh)

## TODO

- [ ] Add more color types ( var, advanced css functions )
- [ ] Add more display modes. E.g - sign column
- [ ] Support custom parsers
- [ ] Options support providing function to enable/disable instead of just boolean
