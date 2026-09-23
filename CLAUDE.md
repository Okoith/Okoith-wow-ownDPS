# CLAUDE.md – Arbeitsanweisung für OwnDPS

Du baust das WoW-Addon **OwnDPS** (Retail 12.1.0, Interface `120100`) in diesem Repository. Die fachliche Beschreibung steht in `SPEC.md`. Lies sie vollständig, bevor du Code schreibst.

## Rollen

- **Dominique** testet im Spiel und gibt Feedback.
- **Koordinator** (Claude in Cowork) prüft Logs und Screenshots und schreibt Folgeaufgaben.
- **Du** setzt um, committest und erstellst Test-Builds.

## Harte Regeln (Midnight Secret Values)

1. Werte aus `C_DamageMeter` sind **im Kampf geheim**. Mit ihnen niemals rechnen, vergleichen, verketten, `tostring` aufrufen oder sie als Tabellen-**Schlüssel** verwenden. Als Tabellen-**Wert** oder in Variablen speichern ist erlaubt.
2. Darstellen nur über Widget-APIs, die Secret Values annehmen: `FontString:SetFormattedText`, `SetText`, `StatusBar:SetMinMaxValues`, `SetValue`, `AbbreviateNumbers`.
3. Nie geheime Werte in SavedVariables schreiben. Vorher `issecretvalue(v)` prüfen, sonst `"<SECRET>"` speichern.
4. Jeder Zugriff auf `C_DamageMeter` und auf Felder der Rückgabe steht in `pcall`.
5. Nicht lesbar zu sein, ist kein Fehlerfall: Die Anzeige muss dann einfach leer oder `-` sein, ohne Lua-Fehler.
6. Kein `COMBAT_LOG_EVENT_UNFILTERED`. Es ist in Midnight für Addons nicht verfügbar.

Die getesteten Fakten stehen in `SPEC.md`, Abschnitt 10. Widersprechen Internetquellen diesen Fakten, gelten die Testergebnisse.

## Referenz

`docs/reference/OwnDPS_Test.lua` ist das Testaddon, mit dem alle Fakten ermittelt wurden. Übernimm daraus die funktionierenden Techniken (Session lesen, Platz finden, Zahlenformat, Trend-Balken, Abschneide-Trick mit Maske). Die Pfeil-Masken liegen in `docs/reference/arrow_up.tga` und `arrow_down.tga`. Kopiere sie nach `media/`.

## Projektstruktur (Vorschlag)

```
OwnDPS/
  OwnDPS.toc
  embeds.xml            # lädt die Bibliotheken aus libs/
  Locales/enUS.lua, deDE.lua
  Core.lua              # Init, AceDB, Events, Ticker
  Data.lua              # C_DamageMeter-Zugriff, Platz, Historie
  Display.lua           # Frame, Textzeile, Trend-Stile
  EditMode.lua          # LibEditMode-Anbindung
  Options.lua           # Settings-Panel, Profile kopieren
  Debug.lua             # Debug-Log in SavedVariables
  media/arrow_up.tga, arrow_down.tga
  .pkgmeta
  .github/workflows/release.yml
  LICENSE (MIT, Copyright Dominique)
  README.md, CHANGELOG.md
```

## Bibliotheken

Über `.pkgmeta` externals einbinden, nicht ins Repo kopieren: LibStub, CallbackHandler-1.0, AceDB-3.0, LibSharedMedia-3.0, LibEditMode. **Prüfe die aktuellen Quell-URLs** in der Dokumentation der jeweiligen Bibliothek, bevor du sie einträgst. `libs/` gehört in `.gitignore`.

## Release-Workflow

- GitHub Actions mit `BigWigsMods/packager`. **Prüfe Version, Namen der Umgebungsvariablen und nötige `permissions`** im aktuellen README des Packagers (https://github.com/BigWigsMods/packager), statt sie aus dem Gedächtnis zu übernehmen.
- Auslöser: Push eines Tags `v*`
- Ziel zunächst nur **GitHub Release** (Zip mit Bibliotheken). CurseForge folgt später, vorbereiten mit leerem `## X-Curse-Project-ID` als Kommentar.
- Test-Builds: Tag `v0.x.y-alpha.N`. Dominique lädt das Zip aus dem Release.

## Arbeitsweise

- In kleinen Schritten arbeiten. Nach jedem Meilenstein: Commit, Tag für ein Test-Build und eine kurze Zusammenfassung mit Testanleitung für Dominique.
- Version in `OwnDPS.toc` (`## Version`) und in `CHANGELOG.md` mit jedem Tag erhöhen.
- Code-Kommentare auf Deutsch oder Englisch, Oberflächentexte nur über Locales.
- Nichts raten. Wenn eine WoW-API unklar ist, im Code defensiv mit `pcall` absichern und im Debugmodus loggen, damit der Test die Antwort liefert.

## Meilensteine

1. **Grundgerüst:** TOC, Locales, AceDB, Frame mit Textzeile `Platz Wert Einheit`, Datenquelle Automatisch, Debugmodus, Release-Workflow. Tag `v0.1.0-alpha.1`.
2. **Trend:** alle vier Stile, Zeitfenster, Toleranz, nur im Kampf sichtbar.
3. **Einstellungen:** Settings-Panel mit allen Optionen aus SPEC Abschnitt 5, LibSharedMedia, Profile kopieren.
4. **Bearbeitungsmodus:** LibEditMode mit Button zu den Einstellungen, Sperren-Option.
5. **Feinschliff:** Sichtbarkeitsregeln, HPS-Modus prüfen, README mit Screenshots-Platzhaltern, `v1.0.0`.
