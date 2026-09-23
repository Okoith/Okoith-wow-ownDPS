# Changelog

## 0.1.0-alpha.1 (2026-09-23)

Meilenstein 1: Grundgerüst.

- TOC für Retail 12.1.0 (Interface 120100), Locales enUS und deDE
- Einstellungen pro Charakter über AceDB-3.0
- Textzeile `Platz Wert Einheit` (Name optional, standardmäßig aus)
- Datenquelle Automatisch (im Kampf aktueller Kampf, sonst Gesamt), Immer aktueller Kampf, Immer Gesamt
- Modus DPS oder HPS
- Im Haustierkampf ausgeblendet
- Debugmodus mit Log in `OwnDPSDebugLog` (max. 5000 Einträge, Secret Values nur als `<SECRET>`)
- Slash-Befehl `/owndps` (Einstellungsmenü folgt in Meilenstein 3)
- Release-Workflow mit BigWigs Packager (GitHub Release bei Tag `v*`)
