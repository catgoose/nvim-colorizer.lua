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

`css = true` preset — enables names, hex, rgb, hsl, oklch all at once.

<!-- gen:default_gallery:start -->
<!-- gen:default_gallery:end -->

## Presets

The `css` and `css_fn` presets enable groups of parsers with a single flag.
Each test shows what the preset enables and what it does not.

<!-- gen:preset_gallery:start -->
<!-- gen:preset_gallery:end -->

## Hex Colors

Each test enables one `hex.*` option. The `hex_all` test enables all hex formats together.

<!-- gen:hex_gallery:start -->
<!-- gen:hex_gallery:end -->

## CSS Functions

Each test enables one CSS function parser. The `css_all` test enables all CSS functions together.

<!-- gen:css_gallery:start -->
<!-- gen:css_gallery:end -->

## Named Colors

Each test enables one name case variant or tailwind. The `names_all` test enables all name styles together.

<!-- gen:names_gallery:start -->
<!-- gen:names_gallery:end -->

## Special Parsers

Each test enables one special parser (xterm, xcolor, css_var_rgb, sass, hooks) with its own fixture.

<!-- gen:special_gallery:start -->
<!-- gen:special_gallery:end -->

## Display Modes

All display tests use the same fixture with `css = true`, showing how different
`display.mode` settings render the same colors.

<!-- gen:display_gallery:start -->
<!-- gen:display_gallery:end -->
