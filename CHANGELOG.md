# Changelog

## 0.2.0-alpha.1 (2026-09-23)

Meilenstein 2: Trend.

- Trend-Indikator mit vier Stilen: Pfeil (Standard), Kästchen, Balken, Aus
- Pfeil und Kästchen nutzen den Abschneide-Trick, Pfeilform über Masken aus `media/`
- Zeitfenster (Standard 3 s, 0,5 bis 30 s) und Toleranz (Standard 1 %, 0,1 bis 20 %)
- Farben hoch (grün) und runter (rot), Größe an die Schriftgröße gekoppelt oder eigener Wert
- Indikator nur im Kampf sichtbar, Historie wird bei Kampfbeginn, Reset und Wechsel von Modus oder Datenquelle geleert
- Neue Befehle: `/owndps trend`, `/owndps window`, `/owndps tolerance`, `/owndps trendsize`
- Debug-Log: Trend-Status pro Sekunde im Kampf

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
