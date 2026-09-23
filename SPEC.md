# OwnDPS – Spezifikation v1.0

Stand: 23.09.2026 · Zielversion WoW Retail 12.1.0 (Interface `120100`)

## 1. Ziel

OwnDPS zeigt in **einer Zeile** die eigene DPS (oder HPS), die eigene Platzierung und einen Trend-Indikator. Nichts sonst. Die Daten kommen ausschließlich aus Blizzards `C_DamageMeter`-API.

Beispiel der Anzeige:

```
1. Oktania 495.1k DPS ▲
```

Aufbau: `[Platz] [Name] [Wert] [Einheit] [Trend]`. Jedes Element außer dem Wert ist abschaltbar.

## 2. Anzeige

| Element | Inhalt | Standard | Option |
|---|---|---|---|
| Platz | `1.` (nur die Zahl mit Punkt, **kein** „von 4“) | an | an/aus |
| Name | eigener Charaktername (`UnitName("player")`) | **aus** | an/aus, optional Klassenfarbe |
| Wert | `123.4k`, `12.3M`, `1.2B`, unter 1000 ganze Zahl | immer | – |
| Einheit | `DPS` bzw. `HPS` | an | an/aus |
| Trend | siehe Abschnitt 4 | Stil „Pfeil“ | Stil wählbar |

### Zahlenformat

`AbbreviateNumbers(value, options)` mit eigenem `breakpointData` (eine Nachkommastelle). Diese Konfiguration ist im Spiel getestet und funktioniert **auch mit Secret Values im Kampf**:

```lua
local ABBREV_OPTS = {
  breakpointData = {
    { breakpoint = 1e9, abbreviation = "B", significandDivisor = 1e8, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e6, abbreviation = "M", significandDivisor = 1e5, fractionDivisor = 10, abbreviationIsGlobal = false },
    { breakpoint = 1e3, abbreviation = "k", significandDivisor = 1e2, fractionDivisor = 10, abbreviationIsGlobal = false },
  },
}
```

Den Text immer über `FontString:SetFormattedText()` setzen. Keine Lua-Stringverkettung mit dem Ergebnis, denn im Kampf ist auch der formatierte String geheim.

### Modus DPS / HPS

Umschalter in den Einstellungen. DPS nutzt `Enum.DamageMeterType.Dps`, HPS nutzt `Enum.DamageMeterType.Hps`. Platz, Wert und Trend beziehen sich immer auf den gewählten Modus.
**Hinweis:** HPS ist noch nicht im Spiel getestet. Das erste Test-Build muss es mit prüfen.

### Welche Session wird angezeigt

Einstellung „Datenquelle“:

- **Automatisch** (Standard): im Kampf `Current`, außerhalb des Kampfs `Overall`
- **Immer aktueller Kampf**
- **Immer Gesamt**

Blizzard setzt die Gesamt-Session beim Betreten eines Dungeons selbst zurück (Event `DAMAGE_METER_RESET`, getestet). OwnDPS setzt **nichts** selbst zurück.

## 3. Platzierung

Platz = Index des Eintrags mit `isLocalPlayer == true` in `session.combatSources`. Die Liste ist von Blizzard bereits sortiert. Index und `isLocalPlayer` sind nie geheim (getestet). Follower-NPCs zählen mit.

## 4. Trend-Indikator

### Prinzip

Im Kampf sind alle DPS-Werte geheim. Lua kann sie nicht vergleichen. Der Trend wird deshalb **von WoW beim Zeichnen** entschieden:

- Der aktuelle Wert und der Wert von vor N Sekunden werden in einer Historie gespeichert (Speichern von Secret Values ist erlaubt).
- „Hoch“-Anzeige: `StatusBar:SetMinMaxValues(0, alt)` und `SetValue(aktuell)`
- „Runter“-Anzeige: `SetMinMaxValues(0, aktuell)` und `SetValue(alt)`

### Stile (Einstellung „Trend-Stil“)

| Stil | Umsetzung | Getestet |
|---|---|---|
| **Pfeil** (Standard) | Abschneide-Trick (siehe unten) mit Pfeil-Maske ▲/▼ an derselben Stelle | ja |
| **Kästchen** | Abschneide-Trick, zwei Kästchen übereinander (oben hoch, unten runter), bei „stabil“ beide an | ja |
| **Balken** | zwei normale vertikale Balken, der volle zeigt die Richtung, die Füllung des anderen zeigt die Stärke | ja |
| **Aus** | kein Indikator | – |

**Abschneide-Trick:** Ein sehr langer vertikaler StatusBar (Höhe = Indikatorgröße / Toleranz) hängt in einem kleinen Frame mit `SetClipsChildren(true)`. Sichtbar ist nur das oberste Stück. Es ist nur gefüllt, wenn `Wert >= (1 - Toleranz) * Maximum`. Pfeilform über `CreateMaskTexture()` mit eigener TGA (weiß auf transparent), `CLAMPTOBLACKADDITIVE`, auf `GetStatusBarTexture()` angewendet. Referenzcode: `docs/reference/OwnDPS_Test.lua`.

### Regeln

- Trend-Indikator nur **im Kampf** sichtbar (`InCombatLockdown()` ist lesbar).
- Historie bei `PLAYER_REGEN_DISABLED` leeren.
- Beim Zeitfenster „keine Daten“: Indikator leer.

### Einstellungen zum Trend

| Option | Standard | Bereich |
|---|---|---|
| Zeitfenster | 3 s | 0,5–30 s |
| Toleranz (nur Pfeil/Kästchen) | 1 % | 0,1–20 % |
| Farbe hoch | grün | Farbwähler |
| Farbe runter | rot | Farbwähler |
| Größe des Indikators | an Schriftgröße gekoppelt | optional eigener Wert |

## 5. Darstellung und Einstellungen

### Allgemein

- Schriftart über **LibSharedMedia-3.0**
- Schriftgröße
- Kontur: keine / dünn / dick; Schatten an/aus
- Farben einzeln: Platz, Name, Wert, Einheit (Name optional in Klassenfarbe)
- Hintergrund: Farbe und Transparenz (Standard: transparent)
- Rahmen: an/aus, Farbe
- Skalierung und Gesamt-Transparenz

### Position

- Verschieben und Größe über den **WoW-Bearbeitungsmodus** mit **LibEditMode**
- Im Bearbeitungsmodus-Dialog zusätzlich ein Button „Weitere Einstellungen“, der das OwnDPS-Einstellungsfenster öffnet
- Option **„Sperren“**: Das Fenster lässt sich dann auch im Bearbeitungsmodus nicht verschieben
- Slash-Befehl zum Zurücksetzen der Position

### Sichtbarkeit (Einstellung „Anzeigen“)

- Immer (Standard)
- Nur in Instanzen
- Nur in Gruppe
- Nur im Kampf

Immer ausgeblendet im Haustierkampf (`RegisterStateDriver(frame, "visibility", "[petbattle] hide; ...")`, getestet). Optional zusätzlich im Fahrzeug (`[vehicleui]`).

### Einstellungsmenü

- Eintrag in den Blizzard-Einstellungen unter **AddOns** (Settings API)
- Slash `/owndps` öffnet das Menü

### Profile

- Einstellungen **pro Charakter** (AceDB-3.0, Standardprofil = Charakter)
- Funktion „Einstellungen übernehmen von …“ (Auswahlliste der anderen Charaktere, `CopyProfile`)
- Zurücksetzen auf Standard

## 6. Debugmodus

- Schalter in den Einstellungen und `/owndps debug on|off`
- Schreibt ein Log in die SavedVariables (`OwnDPSDebugLog`), Ringpuffer mit maximal 5000 Einträgen
- Secret Values werden **nie** gespeichert, nur als `"<SECRET>"` markiert (Prüfung mit `issecretvalue`)
- Inhalt: Version, Build, Locale, Klasse, Events (Kampfbeginn/-ende, Reset, Instanzwechsel), Fehler aus `pcall`, einmal pro Sekunde im Kampf ein Statuseintrag (Modus, Platz, Anzahl, ob die API-Aufrufe erfolgreich waren)
- `/owndps debug clear` leert das Log

## 7. Sprache

deDE und enUS. Alle Texte über eine Locale-Tabelle, Fallback enUS.

## 8. Technik

- Aktualisierung alle 0,25 s (Ticker) plus Reaktion auf `DAMAGE_METER_CURRENT_SESSION_UPDATED`
- Alle `C_DamageMeter`-Aufrufe und Feldzugriffe in `pcall`
- Keine Arithmetik, keine Vergleiche, keine Stringverkettung mit Werten, die geheim sein können
- Bibliotheken über `.pkgmeta` externals (nicht im Repo): LibStub, CallbackHandler-1.0, AceDB-3.0, LibSharedMedia-3.0, LibEditMode

## 9. Veröffentlichung

- GitHub-Repo `OwnDPS`, öffentlich, Lizenz **MIT**
- Versionen nach SemVer mit Git-Tags (`v1.0.0`). Test-Builds als `v0.x.y-alpha.N`
- GitHub Actions mit BigWigs Packager: Bei jedem Tag wird ein Zip mit allen Bibliotheken gebaut und als **GitHub Release** veröffentlicht
- CurseForge-Upload kommt später dazu (Projekt-ID in TOC `X-Curse-Project-ID`, API-Token als Secret)
- `CHANGELOG.md` pflegen

## 10. Getestete Fakten (12.1.0, Build 69933)

| Punkt | Ergebnis |
|---|---|
| Eigene DPS/Schaden/Dauer im Kampf | geheim, kein Rechnen, kein Vergleichen |
| Nach Kampfende | sofort lesbar |
| `AbbreviateNumbers` mit Secret Value | funktioniert, Ergebnis geheim, per `SetFormattedText` darstellbar |
| `breakpointData` für 123.4k | funktioniert |
| Platz (Index) und Anzahl Quellen | im Kampf lesbar |
| `GetSessionDurationSeconds` | im Kampf lesbar |
| GCD über `C_Spell.GetSpellCooldown(61304)` | im Kampf lesbar |
| `StatusBar:SetMinMaxValues/SetValue` mit Secret Values | funktioniert, `GetValue()` danach geheim |
| Abschneide-Trick mit Maske | funktioniert, nur ein Pfeil sichtbar |
| Reset beim Dungeon-Betreten | macht Blizzard selbst (`DAMAGE_METER_RESET`) |
| Haustierkampf | per State Driver ausgeblendet |
| Nach Kampfende zählt Blizzard die Kampfzeit noch 2–3 s weiter | DPS sinkt kurz und springt zurück |
