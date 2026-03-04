#!/bin/bash
# ── Should highlight ─────────────────────────

# Basic colors (0-15)
echo -e "\e[38;5;0m black"    # #x0
echo -e "\e[38;5;1m maroon"   # #x1
echo -e "\e[38;5;9m red"      # #x9
echo -e "\e[38;5;15m white"   # #x15

# Color cube (16-231)
FG_GREEN="\e[38;5;42m"        # #x42
FG_RED="\e[38;5;196m"         # #x196
FG_ORANGE="\e[38;5;208m"      # #x208
FG_YELLOW="\e[38;5;226m"      # #x226

# Grayscale ramp (232-255)
GRAY_DARK="\e[38;5;232m"      # #x232
GRAY_MID="\e[38;5;240m"       # #x240
GRAY_LIGHT="\e[38;5;255m"     # #x255

# ── Should NOT highlight ────────────────────

BAD1="#x256"
BAD2="#x42abc"
