---
name: dark-excel
description: Export Excel sheets with a dark theme by default — every cell gets a 262626 background, D9D9D9 text, and pure-black gridlines/borders, unless specific cells are styled otherwise as part of the design. Use whenever generating, writing, or exporting an .xlsx file and a dark look is wanted ("dark excel", "dark-themed spreadsheet", "export this as a dark workbook").
---

# Dark Excel

Export Excel workbooks with a dark palette as the **default** for every cell on every
sheet. Per-cell design choices override the default — the theme is the floor, not a
straitjacket.

## The defaults

| Element | Hex | openpyxl |
|---|---|---|
| Cell background | `262626` | `PatternFill(start_color="FF262626", fill_type="solid")` |
| Cell text | `D9D9D9` | `Font(color="FFD9D9D9")` |
| Dividers / lines / borders | pure black `000000` | `Side(style="thin", color="FF000000")` |

openpyxl colours are ARGB — prefix each hex with `FF` (fully opaque).

## How to apply it

Style a **whole viewport on every sheet** after the data is written — not just the cells
you happen to touch, but the full screen the user scrolls. Default to at least 1000 rows
× 100 columns (expanding if the data is larger). The point is a uniform dark surface, so
the empty cells around the content read as part of the theme rather than blank white.

Two parts to "lines are pure black":
1. **Borders** on every cell (so the grid reads as black dividers even where Excel's own
   gridlines are hidden behind a fill).
2. **Hide Excel's default gridlines** (`ws.sheet_view.showGridLines = False`) so the only
   lines visible are your black borders — otherwise the faint default grid fights the
   theme.

Use this helper. It applies the theme to a worksheet without clobbering any per-cell
overrides you pass in `skip`:

```python
from openpyxl.styles import PatternFill, Font, Border, Side
from openpyxl.worksheet.worksheet import Worksheet

DARK_FILL = PatternFill(start_color="FF262626", end_color="FF262626", fill_type="solid")
DARK_FONT = Font(color="FFD9D9D9")
BLACK_SIDE = Side(style="thin", color="FF000000")
BLACK_BORDER = Border(left=BLACK_SIDE, right=BLACK_SIDE, top=BLACK_SIDE, bottom=BLACK_SIDE)


def apply_dark_theme(
    ws: Worksheet,
    skip: set[str] | None = None,
    min_rows: int = 1000,
    min_cols: int = 100,
) -> None:
    """Default a whole viewport of cells to the dark palette.

    Paints at least `min_rows` x `min_cols` so the dark surface fills the screen the
    user actually scrolls, not only the cells holding content. If the sheet's used
    range is larger, the viewport expands to cover it.

    Cells whose coordinate is in `skip` keep whatever styling they already have —
    that's how per-cell design overrides survive.
    """
    skip = skip or set()
    ws.sheet_view.showGridLines = False
    max_row = max(min_rows, ws.max_row)
    max_col = max(min_cols, ws.max_column)
    for row in ws.iter_rows(min_row=1, max_row=max_row, min_col=1, max_col=max_col):
        for cell in row:
            if cell.coordinate in skip:
                continue
            cell.fill = DARK_FILL
            cell.border = BLACK_BORDER
            # Preserve bold/size/name; only force the colour.
            f = cell.font
            cell.font = Font(
                name=f.name, size=f.size, bold=f.bold, italic=f.italic,
                color="FFD9D9D9",
            )
```

Apply it to **every** sheet just before saving:

```python
for ws in wb.worksheets:
    apply_dark_theme(ws)
wb.save(path)
```

## Overrides

When the design calls for specific cells to look different (a coloured header band, a
red warning total, a highlighted KPI), set those cells' styles **first**, collect their
coordinates, and pass them as `skip` so the theme pass leaves them alone. Equally fine to
run the theme pass first and restyle the special cells afterwards — whichever reads
cleaner for the sheet. The contract is just: explicit per-cell design wins, the dark
default fills everything else.

## Running it

openpyxl is third-party, so run any generation script with `uv run` (e.g.
`uv run python build_workbook.py`). If openpyxl isn't available, add it: `uv add openpyxl`
or `uv run --with openpyxl python build_workbook.py`.
