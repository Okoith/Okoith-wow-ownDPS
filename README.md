# OwnDPS

World of Warcraft addon (Retail 12.1.0) that shows your own DPS or HPS, your rank and a trend indicator in a single line:

```
1. 495.1k DPS
```

All data comes from Blizzard's `C_DamageMeter` API. The addon does not use the combat log.

## Status

Early test builds (`v0.x.y-alpha.N`). The trend indicator, settings panel and Edit Mode support will follow.

## Installation

Download the zip from the [Releases](../../releases) page and extract it to `World of Warcraft\_retail_\Interface\AddOns\`.

## Commands

| Command | Effect |
|---|---|
| `/owndps` | Help |
| `/owndps mode dps\|hps` | Show damage or healing |
| `/owndps source auto\|current\|overall` | Data source |
| `/owndps toggle rank\|name\|unit` | Show or hide an element |
| `/owndps move` | Unlock or lock the frame for dragging |
| `/owndps reset` | Reset the position |
| `/owndps debug on\|off\|clear\|status` | Debug log (`OwnDPSDebugLog` in SavedVariables) |
| `/owndps status` | Current settings |

## Development

Libraries are fetched by the [BigWigs packager](https://github.com/BigWigsMods/packager) from `.pkgmeta` and are not part of the repository. Pushing a tag `v*` builds a zip and publishes it as a GitHub release.

## License

MIT, see [LICENSE](LICENSE).
