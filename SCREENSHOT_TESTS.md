# Screenshot Tests

Visual regression tests for every parser and display mode. Each test is
CI-generated from a config in
[`scripts/screenshots/configs.lua`](scripts/screenshots/configs.lua) that
enables **one** option against a fixture file, showing exactly which strings
it highlights and which it does not.

**Report an issue:** click the `[N]` link next to any test to open a
pre-filled issue.

## Table of Contents

- [Default](#default)
- [Presets](#presets)
- [Hex Colors](#hex-colors)
- [CSS Functions](#css-functions)
- [Named Colors](#named-colors)
- [Special Parsers](#special-parsers)
- [Display Modes](#display-modes)

## Default

`css = true` preset — enables names, hex, rgb, hsl, oklch, css_var all at once.

<!-- gen:default_gallery:start -->
<table>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B1%5D%20default&body=%2A%2AScreenshot%20index%3A%2A%2A%201%0A%2A%2AConfig%20key%3A%2A%2A%20%60default%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[1]</a> default</strong><br>
<em>css = true (names + hex + rgb + hsl + oklch + css_var)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/default.png" width="600"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
```

</details>
</td>
</tr>
</table>
<!-- gen:default_gallery:end -->

## Presets

The `css` and `css_fn` presets enable groups of parsers with a single flag.
Each test shows what the preset enables and what it does not.

<!-- gen:preset_gallery:start -->
<table>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B2%5D%20preset_css&body=%2A%2AScreenshot%20index%3A%2A%2A%202%0A%2A%2AConfig%20key%3A%2A%2A%20%60preset_css%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[2]</a> preset_css</strong><br>
<em>css = true preset (names + hex + rgb + hsl + oklch + css_var)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/preset_css.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B3%5D%20preset_css_fn&body=%2A%2AScreenshot%20index%3A%2A%2A%203%0A%2A%2AConfig%20key%3A%2A%2A%20%60preset_css_fn%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[3]</a> preset_css_fn</strong><br>
<em>css_fn = true preset (rgb + hsl + oklch only)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/preset_css_fn.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  css_fn = true,
  hex = { default = false },
  names = { enable = false },
}
```

</details>
</td>
</tr>
</table>
<!-- gen:preset_gallery:end -->

## Hex Colors

Each test enables one `hex.*` option. The `hex_all` test enables all hex formats together.

<!-- gen:hex_gallery:start -->
<table>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B4%5D%20hex_rgb&body=%2A%2AScreenshot%20index%3A%2A%2A%204%0A%2A%2AConfig%20key%3A%2A%2A%20%60hex_rgb%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[4]</a> hex_rgb</strong><br>
<em>#RGB (3-digit)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/hex_rgb.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  hex = { default = false, rgb = true },
  names = { enable = false },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B5%5D%20hex_rgba&body=%2A%2AScreenshot%20index%3A%2A%2A%205%0A%2A%2AConfig%20key%3A%2A%2A%20%60hex_rgba%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[5]</a> hex_rgba</strong><br>
<em>#RGBA (4-digit)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/hex_rgba.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  hex = { default = false, rgba = true },
  names = { enable = false },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B6%5D%20hex_rrggbb&body=%2A%2AScreenshot%20index%3A%2A%2A%206%0A%2A%2AConfig%20key%3A%2A%2A%20%60hex_rrggbb%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[6]</a> hex_rrggbb</strong><br>
<em>#RRGGBB (6-digit)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/hex_rrggbb.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  hex = { default = false, rrggbb = true },
  names = { enable = false },
}
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B7%5D%20hex_rrggbbaa&body=%2A%2AScreenshot%20index%3A%2A%2A%207%0A%2A%2AConfig%20key%3A%2A%2A%20%60hex_rrggbbaa%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[7]</a> hex_rrggbbaa</strong><br>
<em>#RRGGBBAA (8-digit)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/hex_rrggbbaa.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  hex = { default = false, rrggbbaa = true },
  names = { enable = false },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B8%5D%20hex_hash_aarrggbb&body=%2A%2AScreenshot%20index%3A%2A%2A%208%0A%2A%2AConfig%20key%3A%2A%2A%20%60hex_hash_aarrggbb%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[8]</a> hex_hash_aarrggbb</strong><br>
<em>#AARRGGBB (QML 8-digit)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/hex_hash_aarrggbb.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  hex = { default = false, hash_aarrggbb = true },
  names = { enable = false },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B9%5D%20hex_0x_aarrggbb&body=%2A%2AScreenshot%20index%3A%2A%2A%209%0A%2A%2AConfig%20key%3A%2A%2A%20%60hex_0x_aarrggbb%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[9]</a> hex_0x_aarrggbb</strong><br>
<em>0xAARRGGBB (prefix hex)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/hex_0x_aarrggbb.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  hex = { aarrggbb = true, default = false },
  names = { enable = false },
}
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B10%5D%20hex_no_hash&body=%2A%2AScreenshot%20index%3A%2A%2A%2010%0A%2A%2AConfig%20key%3A%2A%2A%20%60hex_no_hash%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[10]</a> hex_no_hash</strong><br>
<em>RRGGBB without # prefix</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/hex_no_hash.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  hex = { default = false, no_hash = true },
  names = { enable = false },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B11%5D%20hex_default&body=%2A%2AScreenshot%20index%3A%2A%2A%2011%0A%2A%2AConfig%20key%3A%2A%2A%20%60hex_default%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[11]</a> hex_default</strong><br>
<em>hex.default (all common formats)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/hex_default.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { hex = { default = true }, names = { enable = false } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B12%5D%20hex_all&body=%2A%2AScreenshot%20index%3A%2A%2A%2012%0A%2A%2AConfig%20key%3A%2A%2A%20%60hex_all%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[12]</a> hex_all</strong><br>
<em>All hex formats combined</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/hex_all.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  hex = { default = true, hash_aarrggbb = true, no_hash = true },
  names = { enable = false },
}
```

</details>
</td>
</tr>
</table>
<!-- gen:hex_gallery:end -->

## CSS Functions

Each test enables one CSS function parser. The `css_all` test enables all CSS functions together.

<!-- gen:css_gallery:start -->
<table>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B13%5D%20css_rgb&body=%2A%2AScreenshot%20index%3A%2A%2A%2013%0A%2A%2AConfig%20key%3A%2A%2A%20%60css_rgb%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[13]</a> css_rgb</strong><br>
<em>rgb() / rgba() functions</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/css_rgb.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { rgb = { enable = true } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B14%5D%20css_hsl&body=%2A%2AScreenshot%20index%3A%2A%2A%2014%0A%2A%2AConfig%20key%3A%2A%2A%20%60css_hsl%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[14]</a> css_hsl</strong><br>
<em>hsl() / hsla() functions</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/css_hsl.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { hsl = { enable = true } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B15%5D%20css_oklch&body=%2A%2AScreenshot%20index%3A%2A%2A%2015%0A%2A%2AConfig%20key%3A%2A%2A%20%60css_oklch%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[15]</a> css_oklch</strong><br>
<em>oklch() function</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/css_oklch.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { oklch = { enable = true } }
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B16%5D%20css_hwb&body=%2A%2AScreenshot%20index%3A%2A%2A%2016%0A%2A%2AConfig%20key%3A%2A%2A%20%60css_hwb%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[16]</a> css_hwb</strong><br>
<em>hwb() function (CSS Color Level 4)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/css_hwb.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { hwb = { enable = true } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B17%5D%20css_lab&body=%2A%2AScreenshot%20index%3A%2A%2A%2017%0A%2A%2AConfig%20key%3A%2A%2A%20%60css_lab%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[17]</a> css_lab</strong><br>
<em>lab() function (CIE Lab)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/css_lab.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { lab = { enable = true } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B18%5D%20css_lch&body=%2A%2AScreenshot%20index%3A%2A%2A%2018%0A%2A%2AConfig%20key%3A%2A%2A%20%60css_lch%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[18]</a> css_lch</strong><br>
<em>lch() function (CIE LCH)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/css_lch.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { lch = { enable = true } }
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B19%5D%20css_color_fn&body=%2A%2AScreenshot%20index%3A%2A%2A%2019%0A%2A%2AConfig%20key%3A%2A%2A%20%60css_color_fn%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[19]</a> css_color_fn</strong><br>
<em>color() function (srgb, display-p3, a98-rgb, etc.)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/css_color_fn.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css_color = { enable = true } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B20%5D%20css_hsluv&body=%2A%2AScreenshot%20index%3A%2A%2A%2020%0A%2A%2AConfig%20key%3A%2A%2A%20%60css_hsluv%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[20]</a> css_hsluv</strong><br>
<em>hsluv() / hsluvu() functions</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/css_hsluv.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { hsluv = { enable = true } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B21%5D%20css_all&body=%2A%2AScreenshot%20index%3A%2A%2A%2021%0A%2A%2AConfig%20key%3A%2A%2A%20%60css_all%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[21]</a> css_all</strong><br>
<em>All CSS color functions combined</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/css_all.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  css_color = { enable = true },
  hsl = { enable = true },
  hsluv = { enable = true },
  hwb = { enable = true },
  lab = { enable = true },
  lch = { enable = true },
  oklch = { enable = true },
  rgb = { enable = true },
}
```

</details>
</td>
</tr>
</table>
<!-- gen:css_gallery:end -->

## Named Colors

Each test enables one name case variant or tailwind. The `names_all` test enables all name styles together.

<!-- gen:names_gallery:start -->
<table>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B22%5D%20names_lowercase&body=%2A%2AScreenshot%20index%3A%2A%2A%2022%0A%2A%2AConfig%20key%3A%2A%2A%20%60names_lowercase%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[22]</a> names_lowercase</strong><br>
<em>lowercase named colors only</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/names_lowercase.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = {
    camelcase = false,
    enable = true,
    lowercase = true,
    uppercase = false,
  },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B23%5D%20names_camelcase&body=%2A%2AScreenshot%20index%3A%2A%2A%2023%0A%2A%2AConfig%20key%3A%2A%2A%20%60names_camelcase%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[23]</a> names_camelcase</strong><br>
<em>CamelCase named colors only</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/names_camelcase.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = {
    camelcase = true,
    enable = true,
    lowercase = false,
    uppercase = false,
  },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B24%5D%20names_uppercase&body=%2A%2AScreenshot%20index%3A%2A%2A%2024%0A%2A%2AConfig%20key%3A%2A%2A%20%60names_uppercase%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[24]</a> names_uppercase</strong><br>
<em>UPPERCASE named colors only</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/names_uppercase.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = {
    camelcase = false,
    enable = true,
    lowercase = false,
    uppercase = true,
  },
}
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B25%5D%20names_tailwind&body=%2A%2AScreenshot%20index%3A%2A%2A%2025%0A%2A%2AConfig%20key%3A%2A%2A%20%60names_tailwind%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[25]</a> names_tailwind</strong><br>
<em>Tailwind CSS color names</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/names_tailwind.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { names = { enable = false }, tailwind = { enable = true } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B26%5D%20names_tailwind_lsp_config&body=%2A%2AScreenshot%20index%3A%2A%2A%2026%0A%2A%2AConfig%20key%3A%2A%2A%20%60names_tailwind_lsp_config%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[26]</a> names_tailwind_lsp_config</strong><br>
<em>Tailwind with lsp table config (parser names only)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/names_tailwind_lsp_config.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = { enable = false },
  tailwind = {
    enable = true,
    lsp = {
      disable_document_color = true,
      enable = false,
      update_names = false,
    },
  },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B27%5D%20names_strip_digits&body=%2A%2AScreenshot%20index%3A%2A%2A%2027%0A%2A%2AConfig%20key%3A%2A%2A%20%60names_strip_digits%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[27]</a> names_strip_digits</strong><br>
<em>strip_digits rejects names ending in digits</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/names_strip_digits.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = { enable = true, lowercase = true, strip_digits = true },
}
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B28%5D%20names_custom&body=%2A%2AScreenshot%20index%3A%2A%2A%2028%0A%2A%2AConfig%20key%3A%2A%2A%20%60names_custom%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[28]</a> names_custom</strong><br>
<em>User-defined custom color names</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/names_custom.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = {
    camelcase = false,
    custom = {
      ["brand-primary"] = "#E63946",
      ["brand-secondary"] = "#457B9D",
      ["ui-danger"] = "#F4A261",
      ["ui-success"] = "#2A9D8F",
      ["ui-warning"] = "#E9C46A",
    },
    enable = true,
    extra_word_chars = "",
    lowercase = false,
    uppercase = false,
  },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B29%5D%20names_extra_word_chars&body=%2A%2AScreenshot%20index%3A%2A%2A%2029%0A%2A%2AConfig%20key%3A%2A%2A%20%60names_extra_word_chars%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[29]</a> names_extra_word_chars</strong><br>
<em>extra_word_chars = "-" (hyphens in names)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/names_extra_word_chars.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = {
    camelcase = false,
    custom = {
      ["brand-primary"] = "#E63946",
      ["brand-secondary"] = "#457B9D",
      ["ui-success"] = "#2A9D8F",
      ["ui-warning"] = "#E9C46A",
    },
    enable = true,
    extra_word_chars = "-",
    lowercase = false,
    uppercase = false,
  },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B30%5D%20names_all&body=%2A%2AScreenshot%20index%3A%2A%2A%2030%0A%2A%2AConfig%20key%3A%2A%2A%20%60names_all%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[30]</a> names_all</strong><br>
<em>All name styles combined</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/names_all.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = {
    camelcase = true,
    enable = true,
    lowercase = true,
    uppercase = true,
  },
  tailwind = { enable = true },
}
```

</details>
</td>
</tr>
</table>
<!-- gen:names_gallery:end -->

## Special Parsers

Each test enables one special parser (xterm, xcolor, css_var_rgb, sass, hooks) with its own fixture.

<!-- gen:special_gallery:start -->
<table>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B31%5D%20special_xterm&body=%2A%2AScreenshot%20index%3A%2A%2A%2031%0A%2A%2AConfig%20key%3A%2A%2A%20%60special_xterm%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[31]</a> special_xterm</strong><br>
<em>Xterm 256-color (#xN)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/special_xterm.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { xterm = { enable = true } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B32%5D%20special_xcolor&body=%2A%2AScreenshot%20index%3A%2A%2A%2032%0A%2A%2AConfig%20key%3A%2A%2A%20%60special_xcolor%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[32]</a> special_xcolor</strong><br>
<em>XColor blending (name!percent)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/special_xcolor.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { names = { enable = false }, xcolor = { enable = true } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B33%5D%20special_css_var_rgb&body=%2A%2AScreenshot%20index%3A%2A%2A%2033%0A%2A%2AConfig%20key%3A%2A%2A%20%60special_css_var_rgb%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[33]</a> special_css_var_rgb</strong><br>
<em>CSS variable RGB (--var: r,g,b;)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/special_css_var_rgb.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css_var_rgb = { enable = true } }
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B34%5D%20special_css_var&body=%2A%2AScreenshot%20index%3A%2A%2A%2034%0A%2A%2AConfig%20key%3A%2A%2A%20%60special_css_var%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[34]</a> special_css_var</strong><br>
<em>CSS custom properties var(--name) resolution</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/special_css_var.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  css = true,
  css_var = { enable = true, parsers = { css = true } },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B35%5D%20special_sass&body=%2A%2AScreenshot%20index%3A%2A%2A%2035%0A%2A%2AConfig%20key%3A%2A%2A%20%60special_sass%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[35]</a> special_sass</strong><br>
<em>Sass $variable color resolution</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/special_sass.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = { enable = false },
  sass = { enable = true, parsers = { css = true } },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B36%5D%20special_sass_pattern&body=%2A%2AScreenshot%20index%3A%2A%2A%2036%0A%2A%2AConfig%20key%3A%2A%2A%20%60special_sass_pattern%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[36]</a> special_sass_pattern</strong><br>
<em>variable_pattern restricts to alpha-only names</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/special_sass_pattern.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = { enable = false },
  sass = {
    enable = true,
    parsers = { css = true },
    variable_pattern = "^%$([%a]+)",
  },
}
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B37%5D%20special_hooks_line_filter&body=%2A%2AScreenshot%20index%3A%2A%2A%2037%0A%2A%2AConfig%20key%3A%2A%2A%20%60special_hooks_line_filter%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[37]</a> special_hooks_line_filter</strong><br>
<em>should_highlight_line skips comment lines</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/special_hooks_line_filter.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
hooks = {
  should_highlight_line = function(...) end -- see configs.lua,
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B38%5D%20special_hooks_color_filter&body=%2A%2AScreenshot%20index%3A%2A%2A%2038%0A%2A%2AConfig%20key%3A%2A%2A%20%60special_hooks_color_filter%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[38]</a> special_hooks_color_filter</strong><br>
<em>should_highlight_color skips black and white</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/special_hooks_color_filter.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
hooks = {
  should_highlight_color = function(...) end -- see configs.lua,
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B39%5D%20special_hooks_transform&body=%2A%2AScreenshot%20index%3A%2A%2A%2039%0A%2A%2AConfig%20key%3A%2A%2A%20%60special_hooks_transform%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[39]</a> special_hooks_transform</strong><br>
<em>transform_color converts all colors to grayscale</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/special_hooks_transform.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
hooks = { transform_color = function(...) end -- see configs.lua }
```

</details>
</td>
</tr>
</table>
<!-- gen:special_gallery:end -->

## Display Modes

All display tests use the same fixture with `css = true`, showing how different
`display.mode` settings render the same colors.

<!-- gen:display_gallery:start -->
<table>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B40%5D%20display_background&body=%2A%2AScreenshot%20index%3A%2A%2A%2040%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_background%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[40]</a> display_background</strong><br>
<em>mode = background (default)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_background.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = { mode = "background" }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B41%5D%20display_foreground&body=%2A%2AScreenshot%20index%3A%2A%2A%2041%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_foreground%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[41]</a> display_foreground</strong><br>
<em>mode = foreground (colored text)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_foreground.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = { mode = "foreground" }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B42%5D%20display_underline&body=%2A%2AScreenshot%20index%3A%2A%2A%2042%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_underline%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[42]</a> display_underline</strong><br>
<em>mode = underline (colored underline via sp)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_underline.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = {
  names = { camelcase = true, enable = true, lowercase = true },
}
display = { mode = "underline" }
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B43%5D%20display_virtualtext_eol&body=%2A%2AScreenshot%20index%3A%2A%2A%2043%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_virtualtext_eol%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[43]</a> display_virtualtext_eol</strong><br>
<em>virtualtext at end of line</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_virtualtext_eol.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = { mode = "virtualtext", virtualtext = { position = "eol" } }
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B44%5D%20display_virtualtext_inline&body=%2A%2AScreenshot%20index%3A%2A%2A%2044%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_virtualtext_inline%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[44]</a> display_virtualtext_inline</strong><br>
<em>virtualtext inline after color</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_virtualtext_inline.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = {
  mode = "virtualtext",
  virtualtext = { position = "after" },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B45%5D%20display_virtualtext_before&body=%2A%2AScreenshot%20index%3A%2A%2A%2045%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_virtualtext_before%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[45]</a> display_virtualtext_before</strong><br>
<em>virtualtext before color</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_virtualtext_before.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = {
  mode = "virtualtext",
  virtualtext = { position = "before" },
}
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B46%5D%20display_virtualtext_hl_bg&body=%2A%2AScreenshot%20index%3A%2A%2A%2046%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_virtualtext_hl_bg%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[46]</a> display_virtualtext_hl_bg</strong><br>
<em>virtualtext eol with hl_mode = background</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_virtualtext_hl_bg.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = {
  mode = "virtualtext",
  virtualtext = { hl_mode = "background", position = "eol" },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B47%5D%20display_vt_before_hl_bg&body=%2A%2AScreenshot%20index%3A%2A%2A%2047%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_vt_before_hl_bg%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[47]</a> display_vt_before_hl_bg</strong><br>
<em>virtualtext before with hl_mode = background</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_vt_before_hl_bg.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = {
  mode = "virtualtext",
  virtualtext = { hl_mode = "background", position = "before" },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B48%5D%20display_vt_after_hl_bg&body=%2A%2AScreenshot%20index%3A%2A%2A%2048%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_vt_after_hl_bg%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[48]</a> display_vt_after_hl_bg</strong><br>
<em>virtualtext after with hl_mode = background</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_vt_after_hl_bg.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = {
  mode = "virtualtext",
  virtualtext = { hl_mode = "background", position = "after" },
}
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B49%5D%20display_vt_char_circle&body=%2A%2AScreenshot%20index%3A%2A%2A%2049%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_vt_char_circle%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[49]</a> display_vt_char_circle</strong><br>
<em>virtualtext with char = ●</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_vt_char_circle.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = {
  mode = "virtualtext",
  virtualtext = { char = "●", position = "eol" },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B50%5D%20display_vt_char_block&body=%2A%2AScreenshot%20index%3A%2A%2A%2050%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_vt_char_block%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[50]</a> display_vt_char_block</strong><br>
<em>virtualtext with char = █</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_vt_char_block.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = {
  mode = "virtualtext",
  virtualtext = { char = "█", position = "eol" },
}
```

</details>
</td>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B51%5D%20display_bg_contrast&body=%2A%2AScreenshot%20index%3A%2A%2A%2051%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_bg_contrast%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[51]</a> display_bg_contrast</strong><br>
<em>background mode with custom contrast colors</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_bg_contrast.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = {
  background = { bright_fg = "#1a1a2e", dark_fg = "#e0e0ff" },
  mode = "background",
}
```

</details>
</td>
</tr>
<tr>
<td align="center">
<strong><a href="https://github.com/catgoose/nvim-colorizer.lua/issues/new?title=Screenshot%20issue%3A%20%5B52%5D%20display_priority&body=%2A%2AScreenshot%20index%3A%2A%2A%2052%0A%2A%2AConfig%20key%3A%2A%2A%20%60display_priority%60%0A%0A%2A%2ADescribe%20the%20issue%3A%2A%2A%0A">[52]</a> display_priority</strong><br>
<em>custom priority (default=50, lsp=300)</em><br>
<img src="https://raw.githubusercontent.com/catgoose/screenshots/main/nvim-colorizer.lua/display_priority.png" width="400"><br>
<details><summary>Config</summary>

```lua
parsers = { css = true }
display = {
  mode = "background",
  priority = { default = 50, lsp = 300 },
}
```

</details>
</td>
<td></td>
<td></td>
</tr>
</table>
<!-- gen:display_gallery:end -->