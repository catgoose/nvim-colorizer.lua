#!/usr/bin/env bash

cd test/css-var || exit

nvim --clean -u ../minimal-css-var.lua main.css
