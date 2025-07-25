-- Colorizer setup opts
local opts = {
  filetypes = {
    "*",
    "!dashboard",
    lua = {
      names = true,
      names_opts = {
        lowercase = true,
        camelcase = true,
        uppercase = true,
        strip_digits = false,
      },
      tailwind = true,
      names_custom = {
        [" NOTE:"] = "#5CA204",
        ["TODO: "] = "#3457D5",
        [" WARN: "] = "#EAFE01",
        ["  FIX:  "] = "#FF0000",
        one_two = "#017dac",
        ["three=four"] = "#3700c2",
        ["five@six"] = "#e9e240",
        ["seven!eight"] = "#a9e042",
        ["nine!!ten"] = "#09e392",
        ["'r'"] = "#FF0000",
        ['"r"'] = "#FF0000",
        ["'g'"] = "#00FF00",
        ['"g"'] = "#00FF00",
        ["'b'"] = "#0000FF",
        ['"b"'] = "#0000FF",
        ["'c'"] = "#00FFFF",
        ['"c"'] = "#00FFFF",
        ["'m'"] = "#FF00FF",
        ['"m"'] = "#FF00FF",
        ["'y'"] = "#FFFF00",
        ['"y"'] = "#FFFF00",
        ["'k'"] = "#000000",
        ['"k"'] = "#000000",
        ["'w'"] = "#FFFFFF",
        ['"w"'] = "#FFFFFF",
      },
    },
  },
  buftypes = { "*", "!prompt", "!popup" },
  user_commands = true,
  user_default_options = {
    names = true,
    names_opts = {
      lowercase = true,
      camelcase = true,
      uppercase = true,
      strip_digits = false,
    },
    names_custom = function()
      local colors = require("kanagawa.colors").setup()
      return colors.palette
    end,
    RGB = true,
    RGBA = true,
    RRGGBB = true,
    RRGGBBAA = true,
    AARRGGBB = true,
    rgb_fn = true,
    hsl_fn = true,
    css = true,
    css_fn = true,
    xterm = true,
    mode = "background",
    tailwind = true,
    sass = { enable = true, parsers = { css = true } },
    virtualtext = "■",
    virtualtext_inline = false,
    virtualtext_mode = "foreground",
    lazy_load = true,
    always_update = false,
  },
}

return opts

--[[ TEST CASES

0xFFFFFFF1 -- why does this highlight?

SUCCESS CASES:
-- Xterm 256-color codes:
#x0      -- black         #000000
#x1      -- maroon        #800000
#x2      -- green         #008000
#x3      -- olive         #808000
#x4      -- navy          #000080
#x5      -- purple        #800080
#x6      -- teal          #008080
#x7      -- silver        #c0c0c0
#x8      -- grey          #808080
#x9      -- red           #ff0000
#x10     -- lime          #00ff00
#x11     -- yellow        #ffff00
#x12     -- blue          #0000ff
#x13     -- fuchsia       #ff00ff
#x14     -- aqua          #00ffff
#x15     -- white         #ffffff
#x16     -- start of color cube #000000
#x17     -- color cube #00005f
#x21     -- color cube #0000ff
#x51     -- color cube #00ff00
#x88     -- color cube #870000
#x160    -- color cube #d70000
#x231    -- color cube #ffffff
#x232    -- grayscale ramp #080808
#x243    -- grayscale ramp #767676
#x254    -- grayscale ramp #e4e4e4
#x255    -- last grayscale #eeeeee
#x000 #000000
#x099 #5fafd7
#x42 #00d75f #x43 #00d787
#x42, #00d75f
#x42 #00d75f #x43 #00d787

-- Xterm ANSI escape codes:
\e[38;5;0m #000000
\e[38;5;1m #800000
\e[38;5;2m #008000
\e[38;5;3m #808000
\e[38;5;4m #000080
\e[38;5;5m #800080
\e[38;5;6m #008080
\e[38;5;7m #c0c0c0
\e[38;5;15m #ffffff
\e[38;5;16m #000000
\e[38;5;21m #0000ff
\e[38;5;51m #00ff00
\e[38;5;42m #00d75f
\e[38;5;43m #00d787
\e[38;5;88m #870000
\e[38;5;160m #d70000
\e[38;5;231m #ffffff
\e[38;5;232m #080808
\e[38;5;243m #767676
\e[38;5;254m #e4e4e4
\e[38;5;255m #eeeeee
\e[38;5;99m #af5f87
\e[38;5;200m #ff00af
\e[38;5;201m #ff00d7
\e[38;5;202m #ff005f
\e[38;5;220m #ffff00
\e[38;5;226m #ffff5f
\e[38;5;250m #c6c6c6
\e[38;5;251m #d0d0d0
\e[38;5;252m #dadada
\e[38;5;253m #e4e4e4
\e[38;5;000m #000000
\e[38;5;099m #5fafd7
\e[38;5;42m #00d75f \e[38;5;43m #00d787
\e[38;5;42m, #00d75f
\e[38;5;42m #00d75f \e[38;5;43m #00d787

[38;5;42m #00d75f

CSS Named Colors:
olive -- do not remove
cyan magenta gold chartreuse lightgreen pink violet orange
lightcoral lightcyan lemonchiffon papayawhip peachpuff
blue gray lightblue gray100 white gold blue
Blue LightBlue Gray100 White
Gray Gray Gray
gray100     gray20      gray30
White white blue blue blue pink pink pink

Names options: casing, strip digits
deepskyblue deepskyblue1
DeepSkyBlue DeepSkyBlue2
DEEPSKYBLUE DEEPSKYBLUE3

Extra names:
From function defined in `user_default_options`
  oniViolet oniViolet2 crystalBlue springViolet1 springViolet2 springBlue
  lightBlue waveAqua2

Custom names with non-alphanumeric characters:
From table in filetype definiton (lua)
  one_two three=four five@six seven!eight nine!!ten
   NOTE: TODO:  WARN:   FIX:  .
   NOTE:
   NOTE:  NOTE:
   NOTE:  NOTE: note
  TODO:  todo
  TODO:  TODO: .
  TODO:  TODO:  todo
   WARN:  warn
   WARN:  WARN:  warn
    FIX:  .
    FIX:   fix

'r' 'g' 'b' 'c' 'm' 'y' 'k' 'w'
"r" "g" "b" "c" "m" "y" "k" "w"
r g b c m y k w

Tailwind names:
  accent-blue-100 bg-gray-200 border-black border-x-zinc-300 border-y-yellow-400 border-t-teal-500 border-r-neutral-600 border-b-blue-700 border-l-lime-800 caret-indigo-900 decoration-sky-950 divide-white fill-violet-950 from-indigo-900 shadow-blue-800 stroke-sky-700 text-cyan-500 to-red-400 via-green-300 ring-emerald-200 ring-offset-violet-100

Hexadecimal:
#RGB:
  #F0F
  #FFF #FFA #F0F #0FF #FF0
#RGBA:
  #F0F5
  #FFF5 #FFA5 #F0F5 #0FF5 #FF05
#RRGGBB:
  #FFFF00
  #FFFFFF #FFAA00 #FF00FF #00FFFF #FFFF99
#RRGGBBAA:
  #FFFFFFCC
  #FFFFAA99 #FF77FF99 #00FFFF88
0xRGB:
  0xF0F
  0xFFF 0xFFA 0xF0F 0x0FF 0xFF0
0xRRGGBB:
  0xFFFF00
  0xFFFFFF 0xFFAA00 0xFF00FF 0x00FFFF 0xFFFF99
0xRRGGBBAA:
  0xFFFFFFCC
  0xFFFFAA99 0xFF77FF99 0xFF3F3F88

0xFf32A14B 0xFf32A14B
0x1B29FB 0x1B29FB
0xF0F 0xF0F
0xA3B67CDE 0x7F12D9A5 0x7E43F2 0x34E8D3 0xB3A 0x1CD
#32a14b
#F0F #FF00FF #FFF00F8F #F0F #FF00FF
#FF32A14B
#FFF00F8F
#F0F #F00
#FF00FF #F00
#FFF00F8F #F00
#def
#deadbeef

RGB (standard and percentages):
rgb(    201     82.90   50 /0.5) rgb(   109, 100 ,      100, 0.8)
rgb(30% 20% 50%) rgb(0,0,0) rgb(255 122 127 / 80%)
rgb(255 122 127 / .7) rgba(200,30,0,1) rgba(200,30,0,0.5)
rgb(255, 200, 80)
rgb(255, 255, 255) rgb(255, 240, 200) rgb(240, 180, 120) rgb(80%, 60%, 40%)
rgb(255, 180, 180) rgb(255, 220, 120) rgb(255, 255, 100, 0.8)
rgb(255, 255, 255, 255)
rgb(255000, 255000, 255000, 255000)
rgb(100%, 100%, 100%)
rgb(100000%, 100000%, 100000%)

RGBA:
rgba(255, 240, 200, 0.5)
rgba(255, 255, 255, 1) rgba(255, 220, 180, 0.8) rgba(255, 200, 120, 0.4)
rgba(240, 180, 120, 0.6) rgba(255, 200, 80, 0.9) rgba(255, 180, 100, 0.7)
rgba(255, 255, 255, 1)
rgba(255000, 255000, 255000, 1000)

HSL:
hsl(300 50% 50%) hsl(300 50% 50% / 1) hsl(100 80% 50% / 0.4)
hsl(990 80% 50% / 0.4) hsl(720 80% 50% / 0.4)
hsl(1turn 80% 50% / 0.4) hsl(0.4turn 80% 50% / 0.4) hsl(1.4turn 80% 50% / 0.4)
hsl(60, 100%, 80%)
hsl(0, 100%, 90%) hsl(45, 100%, 70%) hsl(120, 100%, 85%) hsl(240, 100%, 85%)
hsl(300, 80%, 75%) hsl(180, 100%, 80%) hsl(210, 80%, 90%) hsl(90, 100%, 85%)
hsl(255, 100%, 100%)
hsl(10000, 10000%, 10000%)

HSLA:
hsla(300 50% 50%) hsla(300 50% 50% / 1)
hsla(300 50% 50% / 0.4) hsla(300,50%,50%,05)
hsla(360   ,  50%  ,  50%   ,  1.0000000000000001)
hsla(60, 100%, 85%, 0.5)
hsla(0, 100%, 90%, 1) hsla(120, 100%, 85%, 0.8) hsla(240, 100%, 85%, 0.7)
hsla(300, 80%, 75%, 0.6) hsla(180, 100%, 80%, 0.9) hsla(90, 100%, 85%, 0.4)
hsl(255, 100%, 100%, 1)
hsl(255000, 100000%, 100000%, 1000)

################################################################################

FAIL CASES:
matcher#add
Invalid Hexadecimal:
#F #FF #FFF0F #GGGGGG #F0FFF0F #F0FFF0FFF
0xGHI 0x1234 0xFFFFF
#FG0 #ZZZZZZ #12345 #FFFFF0F 0xGGG 0x12345 0xFFFFFG
0xf32A14B 0xf32A14B
0xB29FB 0xB29FB
0x0F 0x0F
0x3B67CDE 0xF12D9A5 0xE43F2 0x4E8D3 0x3A 0xCD
#---
#F0FFF
#F0FFF0F
#F0FFF0FFF
#define

Invalid CSS Named Colors:
ceruleanblue goldenrodlight brightcyan darkmagentapurple
Blueberry Gray1000 BlueGree BlueGray

Invalid RGB:
rgb(10, 1 00, 100) rgb(255, 255, 255, -1) rgb(10,,100) rgb()
rgb(256, 100, 100 rgb(-10, 100, 100) rgb(100, 100)
rgb(100,,100) -- causes error
rgb (10,255,100)
rgb(10, 1 00 ,  100)

Invalid RGBA:
rgba(10, 100) rgba(-10, 0, 255, 0.2)
rgba(100, 100, 100, -0.5)
rgba(100, 100) rgba(255, , 255, 0.5)

Invalid HSL:
hsl(300 50% 50 / 1) hsl(30, 50%, 20%,) hsl()
hsl(300, 50, 50) hsl(300,,50%) hsl(300, 50%,)
hsl(300 50% 50% 1)
hsl(300 50% 50 / 1)

Invalid HSLA:
hsla(120, 50%, 50, -0.1) hsla(300, 50) hsla(30, 100%, 50% 1) hsla()
hsla(300, 50%, 50%, -0.5)
hsla(300, 50, 50%, 0.5) hsla(300, 50%,) hsla(300, 50%, 50% 0.5)
hsla(, 50%, 50%, 0.5)
hsla(10 10% 10% 1)
hsla(300,50%,50,1.0000000000000001)
hsla(300,50,50,1.0000000000000001)
hsla(361,50,50,1.0000000000000001)
]]
