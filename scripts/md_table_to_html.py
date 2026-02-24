#!/usr/bin/env python3
"""Convert GFM pipe tables to HTML <table> and strip <!--toc--> blocks for LDoc."""

import re
import sys


def backticks_to_code(text):
    """Convert markdown `inline code` to <code> tags."""
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", text)


def convert_tables(md):
    """Replace GFM pipe tables with HTML tables."""

    def table_repl(m):
        lines = m.group(0).strip().splitlines()
        # First line = header, second = separator, rest = body
        header_cells = [c.strip() for c in lines[0].strip("|").split("|")]
        rows = []
        for line in lines[2:]:
            cells = [c.strip() for c in line.strip("|").split("|")]
            rows.append(cells)

        html = "<table>\n<thead><tr>\n"
        for cell in header_cells:
            html += f"  <th>{backticks_to_code(cell)}</th>\n"
        html += "</tr></thead>\n<tbody>\n"
        for row in rows:
            html += "<tr>\n"
            for cell in row:
                html += f"  <td>{backticks_to_code(cell)}</td>\n"
            html += "</tr>\n"
        html += "</tbody>\n</table>\n"
        return html

    # Match consecutive lines that start and end with |
    return re.sub(
        r"(?:^\|.+\|[ \t]*\n){3,}",
        table_repl,
        md,
        flags=re.MULTILINE,
    )


def strip_toc(md):
    """Remove <!--toc:start--> ... <!--toc:end--> blocks."""
    return re.sub(
        r"<!--toc:start-->.*?<!--toc:end-->",
        "",
        md,
        flags=re.DOTALL,
    )


def main():
    text = sys.stdin.read()
    text = strip_toc(text)
    text = convert_tables(text)
    sys.stdout.write(text)


if __name__ == "__main__":
    main()
