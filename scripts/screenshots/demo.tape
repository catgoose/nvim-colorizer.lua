# nvim-colorizer.lua demo
#
# Run:  vhs scripts/screenshots/demo.tape
#       make demo

Require nvim

Set Shell "bash"
Set FontSize 14
Set FontFamily "JetBrainsMono Nerd Font"
Set Width 1200
Set Height 600
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms

Output scripts/screenshots/output/demo.gif

Hide
Type "COLORIZER_CONFIG=demo nvim -u scripts/screenshots/init.lua -i NONE scripts/screenshots/fixtures/demo.css"
Enter
Sleep 5s
Show

# ── CSS: hex, rgb, hsl, oklch, named colors ──────────────────────

Sleep 2s

Type "G"
Sleep 200ms
Type "o"
Type "#1D3557 #F4A261 #2A9D8F"
Sleep 800ms

Enter
Type "rgb(100, 200, 255) hsl(300 80% 60%)"
Sleep 800ms

Enter
Type "red coral DeepSkyBlue"
Sleep 800ms

Escape
Sleep 1s

Type ":ColorizerToggle"
Enter
Sleep 1.5s

Type ":ColorizerToggle"
Enter
Sleep 2s

# ── HTML: Tailwind + named colors ────────────────────────────────

Type ":e %:h/demo.html"
Enter
Sleep 2s

Type "G"
Sleep 200ms
Type "o"
Type '<div class="bg-rose-500 text-white p-4">Alert</div>'
Sleep 800ms

Enter
Type '<div class="text-sky-400 bg-slate-900">Nav</div>'
Sleep 800ms

Enter
Type '<span style="color: coral">inline</span>'
Sleep 800ms

Escape
Sleep 2s

# ── Lua: hex without # prefix ───────────────────────────────────

Type ":e %:h/demo.lua"
Enter
Sleep 2s

Type "G"
Sleep 200ms
Type "O"
Type 'accent  = "FF6B6B",'
Sleep 800ms

Enter
Type 'forest  = "2D6A4F",'
Sleep 800ms

Enter
Type 'violet  = "7209B7",'
Sleep 800ms

Escape
Sleep 2s

# ── SCSS: Sass variable resolution ──────────────────────────────

Type ":e %:h/demo.scss"
Enter
Sleep 2s

Type "G"
Sleep 200ms
Type "o"
Type "$info:      #3B82F6;"
Sleep 800ms

Enter
Type "$success:   #10B981;"
Sleep 800ms

Enter
Type ".info { color: $info; background: $success; }"
Sleep 800ms

Escape
Sleep 2s

# ── Shell: xterm 256-color codes ────────────────────────────────

Type ":e %:h/demo.sh"
Enter
Sleep 2s

Type "G"
Sleep 200ms
Type "o"
Type 'FG_LIME="\e[38;5;118m"      # #x118'
Sleep 800ms

Enter
Type 'FG_CORAL="\e[38;5;209m"     # #x209'
Sleep 800ms

Enter
Type 'FG_VIOLET="\e[38;5;135m"    # #x135'
Sleep 800ms

Escape
Sleep 2s

# ── LaTeX: xcolor blending ──────────────────────────────────────

Type ":e %:h/demo.tex"
Enter
Sleep 2s

Type "G"
Sleep 200ms
Type "O"
Type '\textcolor{orange!65}{65\% orange}'
Sleep 800ms

Enter
Type '\textcolor{violet!50}{50\% violet}'
Sleep 800ms

Enter
Type '\textcolor{teal!85}{85\% teal}'
Sleep 800ms

Escape
Sleep 2s

Type ":qa!"
Enter
Sleep 500ms
