# OwnDPS

World of Warcraft addon (Retail 12.1.0) that shows your own DPS or HPS, your rank and a trend indicator in a single line:

```
1. 495.1k DPS ▲
```

All data comes from Blizzard's `C_DamageMeter` API. The addon does not use the combat log.

## Status

Early test builds (`v0.x.y-alpha.N`). The settings panel and Edit Mode support will follow.

## Installation

Download the zip from the [Releases](../../releases) page and extract it to `World of Warcraft\_retail_\Interface\AddOns\`.

## Commands

| Command | Effect |
|---|---|
| `/owndps` | Help |
| `/owndps mode dps\|hps` | Show damage or healing |
| `/owndps source auto\|current\|overall` | Data source |
| `/owndps toggle rank\|name\|unit` | Show or hide an element |
| `/owndps trend arrow\|boxes\|bars\|off` | Trend style (shown in combat only) |
| `/owndps window N` | Trend time window in seconds (0.5 to 30) |
| `/owndps tolerance N` | Trend tolerance in percent (0.1 to 20, arrow and boxes) |
| `/owndps trendsize N` | Indicator size in pixels (0 = font size) |
| `/owndps move` | Unlock or lock the frame for dragging |
| `/owndps reset` | Reset the position |
| `/owndps debug on\|off\|clear\|status` | Debug log (`OwnDPSDebugLog` in SavedVariables) |
| `/owndps status` | Current settings |

## Development

Libraries are fetched by the [BigWigs packager](https://github.com/BigWigsMods/packager) from `.pkgmeta` and are not part of the repository. Pushing a tag `v*` builds a zip and publishes it as a GitHub release.

## License

MIT, see [LICENSE](LICENSE).
