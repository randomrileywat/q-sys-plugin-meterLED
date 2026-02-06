# q-sys-plugin-meterLED

A Q-SYS Lua plugin that converts an audio meter level (dBFS) into a visual LED indicator with dynamic opacity.

## Overview

This plugin reads a dBFS meter input and maps the level to the transparency of an LED indicator control. A user-defined base color in `#RRGGBB` format is combined with the calculated opacity to produce a `#OORRGGBB` color string, which is applied directly to the LED indicator.

## Features

- **dBFS to Opacity Mapping** — Linearly maps a configurable dBFS range (default: -60 to 0) to a 0.0–1.0 opacity value.
- **Hex Color Input** — Accepts a base color in `#RRGGBB` format (e.g. `#00FF00` for green).
- **Dynamic `#OORRGGBB` Output** — Combines the opacity and base color into a single `#OORRGGBB` string and applies it to the LED indicator's `.Color` property.
- **Input Validation** — Validates the hex color format and prints feedback to the debug log.
- **Fallback Behavior** — If no valid color is provided, the plugin falls back to setting the LED's `.Position` property for opacity.

## Controls

| Control | Type | Description |
|---|---|---|
| `dBFS_Input` | Meter | Audio level input in dBFS |
| `ColorInput` | Text | Base LED color in `#RRGGBB` hex format |
| `LED_Indicator` | LED | Visual indicator driven by the plugin |

## Configuration

The following constants can be adjusted at the top of the script:

| Constant | Default | Description |
|---|---|---|
| `DBFS_MIN` | `-60` | dBFS value mapped to fully transparent (opacity 0.0) |
| `DBFS_MAX` | `0` | dBFS value mapped to fully opaque (opacity 1.0) |
| `UPDATE_INTERVAL` | `0.1` | Timer polling interval in seconds |

## Version History

| Version | Date | Author | Notes |
|---|---|---|---|
| v260206.1 | 2026-02-06 | RWatson | Initial release — dBFS-to-opacity mapping, `#OORRGGBB` color output, hex color validation |

## License

MIT License — see [LICENSE](LICENSE) for details.