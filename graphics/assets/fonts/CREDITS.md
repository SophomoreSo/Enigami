# Font credits

Both faces are under the **SIL Open Font License 1.1**, which permits use,
modification and redistribution — including inside a commercial game — as long
as the fonts are not sold on their own and the licence travels with them.

| File | Face | Author |
|---|---|---|
| `Silkscreen-Regular.ttf` | [Silkscreen](https://fonts.google.com/specimen/Silkscreen) | Jason Kottke |
| `PlayfairDisplay-Variable.ttf` | [Playfair Display](https://fonts.google.com/specimen/Playfair+Display) | Claus Eggers Sørensen |

Silkscreen is the pixel face: the title screen's menu, records line and settings
(UiKit's pixel look), and all text drawn in the world (`PixelCamera.draw_text`). Its import is set to **no antialiasing, no hinting and no
subpixel positioning** (`Silkscreen-Regular.ttf.import`) — a bitmap face has
exactly one correct shape per pixel, and letting FreeType smooth it turns the
stems grey. Draw it at whole multiples of 8px for the same reason.

Playfair Display draws one word, `Enigami`, and nothing else. It is a variable
font used at its default weight; `graphics/ui/title_screen.gd` is the only
file that loads it.

Every other screen still uses `ThemeDB.fallback_font`.
