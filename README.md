# HUSTYLE

Hustle in style. A 30 day stock trading game made in Godot 4 for the web.

## Run

Open the folder in Godot 4.7 and press Play. The game starts at `scenes/title.tscn`.

## Adding a stock

1. Export the logo from Figma as PNG at 4x and save it as `assets/logos/<id>.png`.
2. Add one line to `data/stocks.json`:

```json
{ "id": "abcd", "name": "Brand Name", "ticker": "ABCD", "logo": "res://assets/logos/abcd.png", "base_price": 120.50, "style": "normal" }
```

- `base_price` is the starting price on day 1.
- `style` is one of `steady`, `normal`, `wild` or `meme`. Missing or unknown means `normal`.
- `volatility` is optional and overrides the style's daily move range for that stock.
- A missing logo file shows a gray tile.

No code changes are needed. The Market list scrolls.

## Tuning

All numbers are constants at the top of these files:

- `scripts/autoload/market.gd`: styles, crash odds and size, recovery days, meme spikes, intraday wobble.
- `scripts/autoload/game.gd`: starting cash, days, day length, tick speed, buy fee, profit tax, rent, payout tiers and cap.
- `scripts/autoload/board.gd`: Hall of Fame size, nickname length, online board switch.
- `scripts/colors.gd`: colors and layout sizes. Run `tools/build_theme.gd` after changing colors:

```
godot --headless --path . --script res://tools/build_theme.gd
```

## Web export

```
godot --headless --path . --export-release "Web" build/web/index.html
cd build/web && zip -r ../hustyle_web.zip .
```

Upload `build/hustyle_web.zip` to itch.io as an HTML project, tick play in the browser, embed size 1280 by 720.

## Tools

- `tools/smoke_test.tscn` plays a fake run without UI and prints the numbers.
- `tools/broke_preview.tscn` opens the Trading Floor already broke. Add `-- PAYOUT` to see the payout card.

Fonts: Inter by Rasmus Andersson, SIL Open Font License, see `assets/fonts/OFL.txt`.
