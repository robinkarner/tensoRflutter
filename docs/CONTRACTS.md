# CONTRACTS — Schnittstellen-Vertrag nach Gate 0 (Welle 0)

Stand: 2026-07-23 · Grundlage: der reale Code unter `lib/` (Gate 0: `flutter analyze` 0 Issues,
`flutter test` 129/129 grün, `flutter build web --release` ✓ inkl. `sqlite3.wasm`/`drift_worker.js`).

Dieser Vertrag ist die Andockfläche für Welle 1 (S-1…S-4) und Welle 2 (K-1…K-4).
Regeln: Eigner-Verzeichnisse respektieren; Provider aus diesem Dokument NICHT umbenennen oder
duplizieren; bei Detailfragen die Quelldatei lesen (Pfade stehen bei jedem Abschnitt).

---

## 0. Boot- und Reboot-Vertrag (der wichtigste Absatz)

```
appBootProvider (main.dart)                    Future<BootResult>, keepAlive
  ├─ 1. fileStoreProvider   (PdfStore.ready-Pendant; Fehler werden geschluckt, app.js:13)
  └─ 2. projectBootProvider (F-C): KV-Scope setzen → Seeding → Belegstand-Import-Once
        → ThesisRuntime bauen → activeRuntimeProvider.activate(...) → textOverridesProvider.set(...)
```

* **Die Shell rendert erst, wenn `appBootProvider` fertig ist** (Splash „Lade …“ in `main.dart`).
* **Projektwechsel (E8, ersetzt `location.reload()`):**
  `ref.read(projectBootProvider.notifier).activateProject(id)` — setzt den RAW-Key
  `activeProject`, bootet neu, leert `FileStore.pdfStatusCache` (L2-Fix). Navigation nach
  `#/projekt` macht der Aufrufer selbst. Reiner Neuaufbau ohne Wechsel: `.reboot()`.
* **Nach jedem KV-Write an `paraEdits`/`fnEdits`/`titleEdits`** muss der Schreiber selbst
  `textOverridesProvider.notifier.set(...)` nachziehen (oder `kv.watchJson` abonnieren) —
  die Overrides werden nur beim Boot automatisch geladen.
* Alle Index-Provider sind **null-tolerant**: vor `activate(...)` liefern sie leere
  Strukturen (originalgetreu; kein Absturz vor dem Boot).

---

## 1. `core/theme` — Design-Tokens & ThemeData

Dateien: `tokens.dart`, `typography.dart`, `theme.dart`, `color_mix.dart`.

| API | Signatur / Inhalt |
|---|---|
| `BookClothTokens` | `ThemeExtension`; `factory .light()/.dark()`; Zugriff `BookClothTokens.of(context)` |
| Farbfelder | `bg,bgDeep,surface,surface2,surface3,border,borderStrong,ink,ink2,muted,accent,accentStrong,accentInk,accentSoft,accentLine,accentContrast,good/warn/bad(+Soft),ki/kiSoft,lvl1..lvl3(+Soft),cat{Norm,Frist,Akteur,Tech,These,Luecke,Zahl,Abk,Schlag},tag{Venue,Publisher,Oa,Paywall}(+Ink),figBg,figBgPop,wissen,wissenInk,wissenSoft,wissenLine,grid,baseline,magicTop,magicBottom,magicEdge,magicC,magicGlow` |
| Helfer | `List<BoxShadow> shadow1/shadow2/shadowPop` · `LinearGradient magicGrad` · `Color? cat(String key)` · `Color? lvl(int)/lvlSoft(int)` |
| Konstanten | `radius=8, radiusSm=6, radiusXs=4, radiusLg=11, radiusPill=999, topbarH=56, bpStack=720, bpNarrow=900, bpWorkspace=999, bpWide=1200` · Hardcodes `pdfPageBg, searchHit, searchHitOutline, srcTextHighlight, magic*, brandClaude/OpenAi(+Edge), brandDotOn/Demo` · `markFarben` (8er-Beleg-Palette) + `markFarbe(String?)` |
| `BookClothColorMix` | `extension on Color`: `mix(Color other, double pct)` (CSS color-mix), `alphaPct(double pct)` |
| Theme | `ThemeData buildAppTheme(Brightness)` · `appThemeLight` / `appThemeDark` |
| Typografie | `AppFonts` (ui/display/mono/serif/magic/symbols + fallback-Ketten) · `AppFontSizes` (body=15.5, small=13.5, lesen=16.75, h1=27, h2=20, h3=18, h4=16, floor=12) · `AppLineHeights` (tight/ui/body/read) · `AppTextStyles` (body,small,h1..h4,eyebrow,lesen,mono,form,button) |

```dart
final t = BookClothTokens.of(context);
Container(color: t.surface, child: Text('…', style: AppTextStyles.body.copyWith(color: t.ink)));
final hover = t.accent.mix(t.bg, 20); // color-mix(accent 20%, bg)
```

---

## 2. `core/widgets` — wiederverwendbare Bausteine

Dateien: `modal.dart`, `resizable.dart`, `tooltip.dart`, `chips.dart`, `buttons.dart`,
`notice.dart`, `accordion.dart`, `lightbox.dart`, `eyebrow.dart`, `corner_marker.dart`.

| API | Signatur |
|---|---|
| Modal | `Future<T?> showAppModal<T>(context, {required Widget title, required Widget body, VoidCallback? onClose, double maxWidth = 780, bool scrollableBody = true})` · `void closeAppModal()` — Ein-Modal-Semantik: ein neues Modal schließt das alte (inkl. Cleanup-Hook) |
| Resizer | `ResizerHandle({required double Function() read, required ValueChanged<double?> apply, ValueChanged<int?>? persist, VoidCallback? onDone, double min = 220, max = 1100, int dir = 1, Axis axis = horizontal, double thickness = 7, EdgeInsets? stripePadding})` — Doppelklick = Reset (`apply(null)`); global: `ResizerHandle.active : ValueNotifier<Axis?>` (Pendant `body.resizing`) |
| Tooltip | `VizTip.show(context, {required Widget content, required Offset position})` / `VizTip.hide()` — +14 px Versatz, Viewport−10 geklemmt, maxWidth 320 |
| Chips | `AppChip({required String label, String? icon, AppChipVariant variant, bool mini, squared, VoidCallback? onTap})` mit `enum AppChipVariant {neutral, ok, warn, bad, ki, accent}` |
| Beleg-Status (RUND) | `LevelBadge(int level)` (✦/❝/✓, l0 = „offen“) · `kLevelInfo : Map<int,({String icon,label,desc})>` · `LevelDot(int level, {Color? ringColor, double size = 7})` · `LvlBar({required int l1,l2,l3,total, double minWidth = 60})` |
| Fußnoten-Chip | `FnChip(int num, {int level = 0, String? srcShort, bool mini, VoidCallback? onTap, String? tooltip})` — Mono, Status-Punkt + Quellen-Kürzel |
| Struktur (QUADRAT) | `StructureDot({Color? color, double size = 8})` · `CornerMarker` / `CornerMarked({required Widget child})` (8×8-Akzent-Quadrat bei (−1,−1)) |
| Buttons | `AppButton({required Widget child, VoidCallback? onPressed, AppButtonVariant variant, bool small, String? tooltip})` mit `enum {solid, primary, ghost}` |
| Magic | `MagicButton({required String label, VoidCallback? onPressed, MagicVariant variant, MagicPhase phase, String? price, bool priceLive, String? sub, bool unset, bool compact})` · `enum MagicVariant {main, top, dialog}` · `enum MagicPhase {idle, busy, done}` — Kochen-Puls, ✓-Finale, Preis-Slot live. Breite-Einfrieren + Vibration [10,40,10] macht der K-3-Aufrufer |
| Sonstiges | `Notice({required Widget child, NoticeVariant variant})` (`warn/info/ki`) · `Accordion({required Widget title, required Widget body, AccordionVariant variant, bool initiallyOpen, ValueChanged<bool>? onChanged, Widget? trailing})` (`acc`/`section`) · `showLightbox(context, {required Widget image, String? caption})` · `Eyebrow(String text, {Color? color})` / `Eyebrow.bar(...)` |

```dart
await showAppModal(context, title: const Text('Quelle'), body: …);
FnChip(42, level: 2, srcShort: 'DSGVO', onTap: () => showFootnoteModal(context, 42));
```

---

## 3. `core/util` — Format, CRC32/srcHash, Satz-Zerlegung

| API | Signatur |
|---|---|
| `format.dart` | `fmtUsd(num?)` · `fmtEur(num?)` · `fmtTok(int)` · `fmtDate(String?)` · `fmtDeNum(num)` (de-AT, CLDR-Gruppierung U+00A0) · `ellipsize(String, int max)` |
| `crc32.dart` | `Crc32.ofBytes/ofString/hex8` · `srcHashNorm(Object?)` · `srcHashBasis({required String id, String? title, longTitle, author, int? year})` · `srcHashOf({…}) → 'ts-'+hex8` (bit-identisch zum Original) · `srcHashPattern : RegExp` · `srcHashInFilename(String) → String?` |
| `sentences.dart` | `splitSentences(String?) → List<SentenceSpan>` (`{int start,end; String text}`) · `sentenceIndexAt(List<SentenceSpan>, int pos)` · `belegSpan(String pText, int fnNum, {int? storedBack, Iterable<BelegSpanMention> mentions}) → BelegSpanResult? {from,to,sents,text}` — `storedBack` = gespeicherter `belegSpans`-KV-Wert, den der Aufrufer (S-2/S-3) hereinreicht |

---

## 4. `data/models` — typisierte Modelle (Barrel: `models.dart`)

Handgeschriebene unveränderliche Klassen, **tolerante `fromJson`-Fabriken** (falsche Typen werden
konvertiert, unbekannte Felder ignoriert; Alt-Formate W2 werden gelesen). Wichtigste Typen:

| Datei | Typen |
|---|---|
| `thesis.dart` | `Thesis{meta, chapters}` · `ThesisMeta` · `Chapter{id,num,title,page?,pdfPage?,sections}` · `Unit{id,title,level,isIntro,paragraphs,children}` (rekursiv) · `Paragraph{id,type,text,items,footnotes}` + `ParagraphType{text,list,table,figure}` · `FootnoteRef{num,text,sources}` · `FlatFootnote` |
| `section_analysis.dart` | `SectionAnalyse{sectionId,paragraphs}` · `ParagraphAnalyse{kernaussage,sentences,belege,reconstructDivergent,…}` · `SentenceAnalyse{text,einfach,kategorien,marks,wichtig?}` · `Mark{snippet,kategorie}` · `Beleg{num,quellen,claim,fundstelle,suchHinweis}` · `SatzWichtig{kern,stuetz,kontext}` |
| `source.dart` | `Source` (alle Bundle-Felder, `custom`, `file`) + `Source.fromCustom` / `.fallbackDossier` / `.defaultZitierweise` · `SourceKind{artikel,konferenz,norm,report,online,rechtEu,rechtAt}` (+`zitiertNachFundstelle`) · `SourceLinks{official?,file?,vorschlag}` · `Citation` · `Stelle` · `SourceDossier` |
| `meta.dart` | `DataMeta{kapitel,gesamt?,fazit?,analyse,stats?,erklaerbuch?,instanzen?,connections?}` (alles null-tolerant, W3) · `GesamtMeta` · `TimelineEvent` (+`isAt/isErledigt`) · `FazitMeta`/`FazitFinding`/`KapitelFlussKante{from,to,label}` · `AnalyseDocs` · `StatsMeta`/`TopSource` |
| `connections.dart` | `KiConnections` · `KiConnection{id,typ,von,nach,label,text}` · `ConnectionSeite{sectionId,paraId}` |
| `instances.dart` | `Instanzen{defs,items}` (+`item(defId,paraId)`) · `InstanzDef{id,label,color,desc}` (color = CSS-Token-String) |
| `figures.dart` | `FiguresManifest{figuren,tabellen}` · `Figur` · `Tabelle{kopf,zeilen}` |
| `project.dart` | `ProjectRecord` — hält das **rohe JSON** (`raw`, `toJson()` = Passthrough, E7-Bit-Kompatibilität); lazy-Sichten `parsed/generated/registry/figures`; Getter `id/name/created/builtin/builtinVersion/userModified/tex`; `toExportJson()` / `ProjectRecord.fromExportJson` (dt. Fehlertexte) · `RegistryEntry` (+`compileAliases()`) |
| `resolution.dart` | `Resolution{formatVersion,sourceId,stellen,…}` · `ResolutionStelle{footnote,seite?,zitat?,kommentar?,status?}` (W10: keine harte 397er-Grenze) |

---

## 5. `data/bundles` — Assets, Runtime, Indizes (die DATA_*-Welt)

Dateien: `bundle_loader.dart`, `runtime.dart`, `indexes.dart`, `kind_labels.dart`.

**Provider (alle keepAlive):**

| Provider | Typ | Zweck |
|---|---|---|
| `thesisBundleProvider` | `Future<ThesisBundle>` | 6 Assets → `{thesis, sections, sources, meta, figures, builtinProjects}` |
| `activeRuntimeProvider` | `ThesisRuntime?` (Notifier `ActiveRuntime`) | DATA_*-Pendant; `activate(rt)` / `clear()`; null = Boot ausstehend |
| `textOverridesProvider` | `TextOverrideState` (Notifier `TextOverrides`) | `{paraEdits: Map<String,String>, fnEdits: Map<int,String>, titleEdits: Map<String,String>}` (Kapitel-Key `"ch<num>"`); `set(...)` |
| `effectiveThesisProvider` | `Thesis?` | Struktur MIT angewandten Overrides |
| `unitIndexProvider` | `UnitIndex` | `operator[](id)` akzeptiert `"3.2.2"` UND `"3_2_2"`; `UnitIndexEntry{unit,chapter,sectionId,fileId}` |
| `orderedUnitsProvider` | `List<String>` | DFS, nur Units mit Absätzen |
| `fnIndexProvider` | `Map<int, FnIndexEntry>` | `{num, text (effektiv), sources, sectionId, paragraphId}` |
| `findBelegProvider(int num)` | `Beleg?` | U.findBeleg-Port (Familie) |
| `srcByIdProvider` | `Map<String, Source>` | |
| `figByParaProvider` / `tabByParaProvider` | `Map<String, Figur/Tabelle>` | |
| `srcShortProvider(String srcId)` | `String` | Familie = Cache-Ersatz; rein: `computeSrcShort(id, Source?)`, Konstante `srcShortKnown` (20 Kurznamen) |

**Klassen/Funktionen:** `fileIdOf("3.2.2") → "3_2_2"` · `sectionIdOf` (Umkehrung) ·
`ThesisRuntime{projectId, projectName, thesis, sections, sources, meta, figures, erklaerbuch?, instanzen?}`
mit `factory .fromBundle(bundle)`, `factory .fromProjectRecord(rec)` (buildRuntime-Port),
`withMergedCustomSources(List<Map>)`, `static computeStats(...) → StatsMeta` ·
`kindLabels` / `kindIcons` (Bundle-Variante, W5).

```dart
final entry = ref.watch(unitIndexProvider)['3.2.2'];      // oder '3_2_2'
final fn = ref.watch(fnIndexProvider)[42];                 // effektiver Text inkl. fnEdits
final short = ref.watch(srcShortProvider(fn!.sources.first));
```

---

## 6. `data/db` — Drift-Datenbank & KV

Dateien: `database.dart`, `kv.dart`, `seed.dart`, `daos/*.dart`.

* `AppDatabase([QueryExecutor?])` — Tabellen `Projects` (rohes Projekt-JSON; `'default'` NIE in DB),
  `Kv` (PK `(projectId, key)`; `projectId ''` = global + Default-Arbeit), `PdfBlobs`
  (Schlüsselschema `<srcId>` / `inbox:<name>` / `img:<srcId>` / `<srcId>~x…`), `FigImgs`, `OcrTexts`.
  Tests: `AppDatabase(NativeDatabase.memory())`. Provider: `appDatabaseProvider` (keepAlive,
  überlebt den Reboot — nur die Sichten darüber werden neu gebaut).
* **Web:** benötigt `web/sqlite3.wasm` + `web/drift_worker.js` — liegen seit Gate 0 im Repo
  (Herkunft/Update-Pfad: `web/DRIFT-WEB-ARTEFAKTE.md`).
* DAOs (über `db.<name>Dao`): `projectsDao` (`getAll/getById/upsert/deleteById` mit `ProjectRecord`),
  `kvDao` (`read/write/remove/watch(projectId, key)`), `fileBlobsDao`, `figImgsDao`,
  `ocrDao` (`read/write/allForSource`).

**`KvStore` (`kvStoreProvider`, keepAlive)** — das Storage-Layer-Pendant:

| Mitglied | Bedeutung |
|---|---|
| `storeProject : String` | mutierbarer Scope, `''` = Default-Arbeit (wird vom Boot VOR dem Runtime-Aufbau gesetzt) |
| `scopeFor(key)` | PROJECT_KEYS-Logik: nur Keys aus `KvKeys.projectKeys` (26 Stück) werden gescoped |
| `getJson(key, [fallback])` / `setJson` / `remove` / `getMap` / `getList` | JSON-Werte im aktuellen Scope |
| `watchJson(key) : Stream<Object?>` | Live-Beobachtung (dekodiert) |
| `getRawGlobal/setRawGlobal` | RAW-Strings ohne JSON-Hülle (nur `activeProject`) |
| `hasAnyProjectState()` | Import-Once-Prüfung (PROJECT_KEYS ohne `studioLast`, truthy) |

`KvKeys`: alle 26 Projekt-Keys als Konstanten (`belegLevels, annotations, resolutions, pdfManual,
linkOverrides, srcNotes, srcTexts, texEdits, pdfMarks, customSources, kiConnections, textMentions,
fileSearch, dlStatus, paraDock, paraEdits, dockBySection, marksExtra, notebook, studioLast,
assignDismissed, fnEdits, belegSpans, titleEdits, srcDoc, srcExtras`) + globale
(`activeProject` (RAW), `builtinDeleted, belegstandImported, theme, claudeCfg, enhCfg, instDefs,
pdfZoomPref, qColl, qSort, uiLibPct`, …) + `rawKeys = {activeProject}`.

`seed.dart`: `seedBuiltinProjects({dao, kv, builtins})` (Tombstones; Update nur bei höherer
`builtinVersion` && `!userModified`) · `importRepoBelegstandOnce(kv, {bundle, asset}) → Future<bool>`.

```dart
final kv = ref.read(kvStoreProvider);
await kv.setJson(KvKeys.studioLast, '3.2.2');       // landet automatisch im richtigen Scope
final marks = await kv.getMap(KvKeys.pdfMarks);
```

---

## 7. `data/export` — bit-kompatible Formate

| Datei | API |
|---|---|
| `belegstand.dart` | `Belegstand.format('ehds-belegstand') / .version(2)` · `exportState(KvStore, {DateTime? now}) → Future<String>` (22 Bereiche, Feld `notes` ↔ Store `srcNotes`, Indent 1) · `importState(KvStore, String) → Future<int>` (prüft nur `format`; truthy-Overwrite: `{}` überschreibt, null/fehlend nicht) |
| `projekt_format.dart` | `exportProjectJson(ProjectRecord) → String` · `parseProjectImport(String) → ProjectRecord` (dt. Fehlertexte) · `randomBase36(n)` · `newProjectId(name)` (`p-<slug30>-<rand4>`) · `copyProjectId/copyProjectName` |
| `dateiauftrag.dart` | `Dateiauftrag.format/version/zipName/anleitung` (9 Zeilen zeichengenau) · `eintragFor(Source, {linkOffiziell, linkDatei, venue}) → DateiauftragEintrag` (`hash`-Identität via `srcHashOf`, `dateiname = '<hash>.pdf'`) · `auftragJson(List)` · `buildZip(List) → Uint8List` · generisch: `createStoreZip(List<ZipWriteEntry>) → Uint8List` (STORE erzwungen) · `readZip(Uint8List) → List<ZipReadEntry{name, data|error}>` |
| `resolution.dart` | `checkResolution(decoded, {String? activeSourceId, required int footnoteCount}) → ResolutionCheck{ok,stellen,mitPos,mitZitat,ohneNum,probleme}` (W10: Obergrenze dynamisch) · `normalizeResolutionForImport(Map, {required sourceId}) → Map` · `parseResolution(Map) → Resolution` |

---

## 8. `data/repos` — Projekte, Datei-Blobs, Abbildungen

**`ProjectRepository` (`projectRepositoryProvider`, keepAlive)** — `project_repository.dart`:

| Methode | Zweck |
|---|---|
| `list()/get(id)/save(rec)/remove(id)` | Projekt-CRUD (`'default'` virtuell) |
| `setActive(id)` | schreibt NUR den RAW-Key — Reboot macht `ProjectBoot` |
| `removeWithTombstone(rec)` | Löschen + `builtinDeleted`-Tombstone |
| `customSources()/saveCustomSource(map)/removeCustomSource(id)` | manuelle Quellen (KV) |
| `importProject(json, {required Future<bool> Function(String id, String existingName) confirmOverwrite})` | Import; `false` ⇒ Kopie mit neuer id |
| `applyGeneratedFile(rec, filename, obj) → GeneratedApplyResult{rec,label?,registry?,registryError?,applied,unknown}` | 11-Stufen-Dateiname-Mapping des Analysen-Imports |
| `srcLinks(Source) → Future<EffectiveSrcLinks{official,file,isOverride}>` | Link-Kaskade Override > doi.org > url |
| `exportDateiauftrag({sources, hasFile})` | Datei-Auftrag-ZIP |
| `boot(ThesisBundle) → Future<BootResult{runtime, overrides, activeId, activeName, warnings, importedBelegstand}>` | die komplette Boot-Sequenz |

**`ProjectBoot` (`projectBootProvider`, AsyncNotifier keepAlive)**: `build()` bootet und füttert
per Seiteneffekt `activeRuntimeProvider` + `textOverridesProvider`; `reboot()`; `activateProject(id)`.

**`FileStore` (`fileStoreProvider : Future<FileStore>`, keepAlive)** — `file_store.dart`, PdfStore-Pendant:
sync `has(id)/count()/hasImage(srcId)/listInbox()/canRemove(id)`; async `addFiles(Iterable<(String,Uint8List)>)`,
`putData/getData` (Blob → Fallback Asset `assets/sources/<id>.pdf`), `removeFile/clearAll`,
`addInbox/getInboxData/removeInbox/assignInbox(name, srcId)`, `putImage/getImage/removeImage`,
`detectPdf(id, KvStore) → Future<bool?>`, `pdfStatusCache : Map<String,bool?>` + `resetStatusCache()`,
`changes : Stream<void>`. Schlüssel-Helfer `FileKeys.inbox/img/extra/isInbox/isImg`.
Matching: `srcHashOfSource(Source)`, `srcIdByHash(hash, sources)`,
`matchFilename(filename, sources) → FilenameMatch?{id,score,sure}` (Score 100/50/40/25/15).

**`FigStore` (`figStoreProvider : Future<FigStore>`)**: `has/put/getImage/remove/changes`.

```dart
final repo = ref.read(projectRepositoryProvider);
final res = repo.applyGeneratedFile(rec, 'abschnitt_3_2_2.json', decoded);
await ref.read(projectBootProvider.notifier).activateProject('p-sensors-x1y2');
```

---

## 9. `domain` — reine Dart-Ports (Barrel: `domain.dart`)

Alle Klassen sind UI-frei und bauen auf zwei Abstraktionen:

* **`DomainContext`** (`domain_context.dart`) — unveränderliche Daten-Sicht:
  `DomainContext.build({required Thesis thesis, List<Source> sources, Map<String,SectionAnalyse> sections, DataMeta meta, Map<int,String> fnOrigTexts})`;
  Felder `thesis, unitIndex, fnIndex, sources, srcById, orderedUnitIds, sections, meta, fnOrigTexts`;
  Methoden `findBeleg(int)`, `srcShort(String)`.
  **Konstruktion in Widgets:** aus `effectiveThesisProvider` + `activeRuntimeProvider`
  (bei aktiven `fnEdits` muss `fnOrigTexts` aus der UN-überschriebenen Runtime gefüllt werden —
  Vorlage: `core/shell/footnote_modal.dart:66-101`).
* **`DomainStore`** (`domain_store.dart`) — KV-Interface `{Object? read(key); void write(key, value)}`
  mit logischen Keys (`belegLevels`, `kiConnections`, …). `MemoryDomainStore([initial])` für
  Momentaufnahmen/Tests. Für live-persistente Nutzung bauen spätere Wellen einen Adapter auf
  `KvStore` (read = Cache-Schnappschuss, write = `setJson` + Invalidierung).

| Klasse | Kern-API |
|---|---|
| `Levels(ctx, store, {MarksForFn? marksForFn, int Function()? nowMs})` | `entry(num)` · `save(num, Map) → int` (seite/fundstelle→3, zitat→2) · `set/clear` · `info(num) → LevelInfo` (Kaskade gespeichert > Resolution/Annotation > PDF-Mark > KI→1) · `countsFor(nums) → LevelCounts{l0..l3,total}` · `allNums/numsForSource/numsForSection/numsForChapter` · `autoFarbe/farbeFor` · `positionType/positionLabel(sourceId)` · `exportState()/importState(json)` · statisch `levelDefs` (✦/❝/✓ wörtlich), `farben` (8 Hex), `farbHex(key)`. **`marksForFn` bleibt bis S-1 null** — dann hängt S-1 die PdfEngine-Marks ein (`typedef MarksForFn = List<PdfMarkLevelInput{zitat,page,farbe}> Function(String srcId, int fnNum)`) |
| `Connections(ctx, store, {nowMs})` | `all() → List<ConnectionEdge>` (4 Quellen, dedupliziert, gecacht) · `invalidate()` · `forSection(id) → SectionConnections{out, inbound}` · `importKi(Object) → String` (wirft `FormatException`, Original-Texte) · `regeneratePrompt()` · statisch `types` (7 `ConnectionTypeDef{icon,out,inLabel}`) |
| `Mentions(ctx, store)` | `patterns()` · `detect(text, fnSources) → List<RawMention>` · `keyFor(paraId, f)` · `statusEntry(paraId, f)` (migriert Alt-Format in-place) · `setStatus(key, status, srcId, [fn])` · `mergeTarget(Paragraph?, RawMention?) → int?` · `forPara(sectionId, Paragraph?) → List<Mention>` · `scanAll()` · `forSource(srcId)` · `invalidate()` |
| `const StyleCheck()` | `analyzeSentence(text, prevConnector) → StyleVerdict{score,hits,connector}` · `analyzePara(text) → List<FlaggedSentence{start,end,text,score,hits}>` (Schwelle ≥1) |
| `TexParse` | `static parse(String?, {List<Map<String,dynamic>>? registry}) → TexParseResult{ok,errors,warnings,stats?,thesis?,footnotes?,sources?}` (+`toJson()`, `thesisModel`, `sourceModels`); Bausteine `scanPackages/residualScan/extractMeta/sourceFromKey/cleanTex/parseParagraphs`, Konstanten `pkgOk` (52) / `pkgNotes` (21) / `accents` |
| `EditorLogic(ctx, store)` | `edits()/saveEdit/clearEdit` (texEdits) · `reconstruct(sectionId) → String` · `inlineToTex(text)` (nutzt `fnOrigTexts`, NIE fnEdits) · `lint(tex) → LintResult{errs,warns,ok}` (Meldungen wörtlich; W9: `\cite` erlaubt) · `preview(tex) → PreviewDocument` · `fullDocument({String? abstract})` · `exportAllName/sectionExportName(id)` · statisch `replaceCmd(str, cmd, fn)` |
| Preview-Modell | `PreviewDocument{blocks}`: `PreviewHeadingBlock{htmlLevel 2..4}` · `PreviewParagraphBlock` · `PreviewListBlock{ordered, items}` · `PreviewPlaceholderBlock`; Spans `PreviewTextSpan{text,bold,italic}` · `PreviewFootnoteSpan{num,tooltip}` — S-3 rendert daraus Widgets |
| `js_compat.dart` | `jsTruthy` · `jsOr` · `stableSorted` (JS-Sortier-Stabilität) |

```dart
final ctx = DomainContext.build(thesis: t, sources: rt.sources, sections: rt.sections, meta: rt.meta);
final levels = Levels(ctx, MemoryDomainStore({'belegLevels': await kv.getMap(KvKeys.belegLevels)}));
final info = levels.info(42);   // LevelInfo mit level/zitat/seite/quelle …
```

---

## 10. `core/router` — Routen

`routes.dart`: `Routes.studio/doc/quellen/analyse/projekt/hilfe` + Legacy-Konstanten;
Bauhilfen `studioPath({sec,modus,para})`, `quellenPath([id])`, `analysePath({tab,arg})`,
`hilfePath([topic])`, `viewOf(location)` (Topbar-Active-Logik); `RouteParams.sec/modus/para/id/tab/arg/topic`;
`StudioModes.lesen/pruefen/editor` (W4: intern `pruefen`, Label „◉ Analyse“).

`router.dart`: `appRouterProvider → GoRouter` (keepAlive). EINE ShellRoute (`AppShell`) um
`/studio[/:sec[/:modus[/:para]]]`, `/doc`, `/quellen[/:id]`, `/analyse[/:tab[/:arg]]`, `/projekt`,
`/hilfe[/:topic]`; Alt-Routen-Redirects (`/`, `/home`, `/lesen`, `/editor`, `/explorer`,
`/zusammenfassung`); unbekannte Pfade → Studio (kein 404). Web nutzt Hash-URLs (`#/…`-Parität).

```dart
context.go(Routes.studioPath(sec: '3.2.2', modus: StudioModes.pruefen, para: '3_2_2-p4'));
```

---

## 11. `core/shell` — Shell, Topbar, cmdk, Theme, Fußnoten-Modal

| API | Signatur / Vertrag |
|---|---|
| `AppShell({required String location, required Widget child})` | Topbar 56 px + EIN scrollender Main (padding 12 / clamp(14,2vw,26) / 80, minHeight = Viewport−Topbar−60) + Footer am Dokumentende; globaler Strg/⌘+K-Griff. Studio-Vollhöhen-Spalten (S-2) leben IM Main (Dossier 02, Flutter-Hinweis 5) |
| `Topbar({required String location})` | Brand, Mainnav, Aktionen. **Andockstellen (seit Gate 2 gefüllt):** `_WorksPopover` → `WorksMenuCard` (K-2), `_GptPopover` → `GptHubCard` (K-3), 🗄 Speicher-Button → `showStoreModal` (S-4) — Details §15 |
| `activeWorkTitleProvider` | `String` (keepAlive) — Arbeitstitel für den 🗂-Umschalter (46-Zeichen-Kürzung) |
| `AppFooter()` | statisch, exakte Linktexte |
| cmdk | `openCmdk(BuildContext)` · `buildCmdkItems(ProviderContainer) → Future<List<CmdkItem{t,k,go}>>` (public — K-4 erweitert hier) — 8 Ansichten + Abschnitte + Quellen, contains-Filter max 40 |
| Theme | `themeControllerProvider` (AsyncNotifier `ThemeController`, keepAlive): `cycle()`; `enum ThemeSetting{auto,light,dark}` (+`icon ◐☀☾`, `tooltip`, `themeMode`); persistiert KV-Key `theme` (`"light"|"dark"|null`) |
| Fußnoten-Modal | `showFootnoteModal(BuildContext, int num)` — global aufrufbar (fn-chip-Klicks aller Features); Momentaufnahme beim Öffnen; navigiert selbst nach `/quellen/:id` und schließt sich dabei |
| ~~`PlaceholderPage`~~ | Rahmen der Welle-0-Screens — seit Gate 2 GELÖSCHT (alle Screens ersetzt, Datei entfernt) |

**Screens (dünne Hüllen, seit Welle 1/2 alle echt):**
`StudioScreen({sec,modus,para})` · `DocScreen()` · `QuellenScreen({id})` · `WissenScreen({tab,arg})`
· `ProjektScreen()` · `HilfeScreen({topic})` — Konstruktor-Signaturen beibehalten (Router ruft sie).

---

## 12. `main.dart` — Boot

`appBootProvider → Future<BootResult>` (keepAlive; Kette siehe §0) · `ThesisStudioApp`
(Splash → Fehler-Screen mit „Neu versuchen“ → `MaterialApp.router`, Fenstertitel
„Thesis Studio — {Titel(60)}“).

---

## 13. Gate-0-Notizen: Umgebung, Abweichungen, Risiken für Welle 1

1. **Sandbox-Workarounds (nur diese Build-Umgebung):**
   `pubspec.yaml → hooks.user_defines.sqlite3.source: system` (Egress blockt sqlite3-Downloads;
   System-libsqlite3 3.45.1 vorhanden) und Platzhalter-`libpdfium.so` unter
   `.dart_tool/hooks_runner/…/pdfium_dart/…` (leeres ELF — der Hook prüft nur Existenz).
   **Folge:** PDF-Rendering auf DESKTOP braucht außerhalb der Sandbox das echte pdfium-Binary;
   Web ist nicht betroffen (pdfrx nutzt dort `pdfium.wasm` aus dem Paket-Asset).
2. **Drift-Web-Artefakte** `web/sqlite3.wasm` (SQLite 3.53.3, alle 78 von package:sqlite3 3.5.0
   erwarteten Exporte verifiziert) + `web/drift_worker.js` (drift 2.34.2, vorkompiliert) liegen im
   Repo — Herkunft und Update-Pfad in `web/DRIFT-WEB-ARTEFAKTE.md`. Bei drift/sqlite3-Upgrade
   mit aktualisieren. **Laufzeit im Browser ist damit theoretisch komplett, aber noch nicht in
   einem echten Browser rauchgetestet** (Sandbox ohne Chrome) — erster manueller Web-Start in
   Welle 1 sollte DB-Open + Seeding prüfen.
3. **Dokumentierte bewusste Abweichungen:** E8-Reboot statt reload (inkl. L2-Cache-Fix) ·
   W9-`\cite`-Fix · Fokus-Glow als 2px-Border · kein theme-color-Meta im Flutter-Web ·
   `fmtDeNum` gruppiert mit U+00A0 (echtes de-AT-CLDR) · Belegstand hat 22 Bereiche
   (Dossier-Zählfehler „21“) · PROJECT_KEYS = 26 (W1 bestätigt).
4. **Offene Andockpunkte:** works-pop-Inhalt (K-2) · gpt-pop-Inhalt (K-3) · storeModal (S-4) ·
   `Levels.marksForFn` (S-1) · `belegSpans`-Store-Anbindung von `belegSpan` (S-2/S-3) ·
   `createFromTex` = `TexParse.parse` + `newProjectId` + `repo.save` (K-2) ·
   `buildCmdkItems`-Erweiterung (K-4) · Belegstand-Asset `assets/data/belegstand.json`
   existiert nicht (Import-Once ist no-op ohne Datei — wie im Original-Repo).
5. **cupertino_icons-Warnung** beim Web-Build (Font nicht gefunden) ist harmlos — niemand
   referenziert CupertinoIcons; verschwindet, sobald das Paket in einer späteren
   pubspec-Runde entfernt wird (pubspec ist für Feature-Wellen tabu).

---

## 14. Welle-1-Anker (Gate 1) — PDF-Engine, Studio, Quellen

Stand Gate 1: `flutter analyze` 0 Issues · `flutter test` 276 grün · `flutter build web --release` ✓.
Die zentrale Verdrahtung lebt in **`lib/app_wiring.dart`** (`wireAppSlots()` + `installAppWiring(ref)`,
aufgerufen als Schritt 0 von `appBoot` in `main.dart`) — neue Slots/Hooks späterer Wellen dort andocken,
NICHT verstreut in Screens. Test-Vorbild: `test/app_wiring_test.dart`.

### 14.1 PdfEngineView (S-1, `features/pdf/pdf.dart` — Barrel)

```dart
final ctl = PdfEngineController();
PdfEngineView(
  srcId: id, page: 14, fit: true, controller: ctl,
  getActive: () => ActiveBeleg(fn: 42, farbe: 'blau', label: 'Claim(60)'), // null ⇒ „Kein Beleg aktiv“
  onCapture: (c) => /* c.text, c.page, c.fn, c.markId → Levels.save */,
  onMarksChange: ..., compact: false, viewOnly: false, data: bytes?, // Kandidaten-Vorschau
  unavailablePlaceholder: ..., maxScrollHeight: 340);
ctl.goto(7, smooth: true); ctl.search('Begriff'); ctl.refreshActive(); ctl.refresh();
```

Marks: `pdfMarksProvider` (KV `pdfMarks`, Form `{srcId: Mark[]}` 1:1, `addMark/updateMark/removeMark/
marksForFn`) · **`levelsMarksForFnProvider`** liefert die `MarksForFn`-Funktion für `Levels` —
`quellenDomainProvider` watcht sie direkt; `studioDomainProvider` liest den Spiegel
`StudioSlots.marksForFn` (von `installAppWiring` gesetzt + bei jeder Änderung invalidiert).
Nicht-PDF-Quelle: `SrcDocView(srcId)` (Aufrufer prüft `SrcKv.getSrcDoc`). Figuren: `FigureCard(fig,
compact:)` / `TableCard(tab)`.

### 14.2 AssignPanel (S-1) + Hooks

```dart
AssignPanel(srcId: id, collapsed: hasFile || doc != null, // Original: !!has || !!doc
  onDone: ..., onMeta: ..., onCancel: ..., onToggle: ...,
  extraActions: [AssignPanelAction(label: '🤖 Ergänzung', onTap: (refresh) {...})]);
AssignPanelHooks.linkEditModal / .openQuellenseite   // registriert S-4 (registerQuellenHooks)
assignPanelDataProvider(srcId)                        // Datenlage: hasFile, doc, candidates, inbox …
```

### 14.3 Studio-Quellen-Spalte (S-2-Host + S-1-Füllung)

`StudioFileColumn(sectionId)` (layout/studio_file_column.dart) rendert sf-bar → `StudioSlots.fileCard`
→ `StudioSlots.fileView` → sfd-resize → Dock. Zustand: **`studioFileProvider`** (`StudioFileState
{srcId, fn, gen}`; `show()` zählt `gen` hoch = Re-Mount, `setFn()` NICHT, `remount()` erzwingt) ·
`studioSelectionProvider` (= `Studio.sel`) · `studioFileShow(ref, context, srcId, fn, sectionId:)`
(fileShow-Port: Lesen→Analyse-Navigation, Spalte aufklappen) · `studioPdfSearchWhenReady(srcId, term)`
(20×200 ms). Der laufende Engine-Controller steht als `StudioSlots.pdfHandle`
(`StudioPdfHandle{srcId, search, goto, refreshActive, refresh}`); die Slot-Füllungen
(`_StudioFileCard`/`_StudioFileView` inkl. `getActive`/`onCapture`→`Levels.save`) liegen in
`app_wiring.dart`.

### 14.4 RefMode („⌖ Große Ansicht“, S-3)

```dart
openStudioRefMode(context, sectionId: ..., paraId: ..., srcId: ..., fn: ...); // Guard: Absatz ohne Belege ⇒ no-op
```

Erreichbar über `StudioSlots.openRefMode` (⤢ der Quellen-Spalte, „⌖ Große Ansicht“ der Absatzkarte)
UND `QuellenRefModeHook.open(context, srcId)` (⌖ Referenzieren im Quellen-Detail — app_wiring springt
zur ersten Zitierstelle der Quelle). Breite: `refWidthProvider` (KV `uiRefW`, min 240).

### 14.5 Beleg-Dock (S-2-Standardfüllung = kompletter renderFileDock-Port)

`StudioSlots.dockBody` bleibt bewusst **null** — Standard ist `FileDockBody(sectionId, srcId, fn)`
(pruefen/file_dock_body.dart) mit `DockFnSlot` (Farb-/↺-Slot), `BelegChecklist(srcId, fnNum)`
(„⌖ BELEG-NACHWEIS n/3“), `FarbControl`, `SearchChips`. Dock-Views: `dockDefsProvider` /
`dockModeForProvider(sectionId)` (null-Override-Semantik!) / `dockGetFrom/dockSetIn/dockAutoFor/
dockCloseSection/dockLabelOf/dockIsTextOf` (layout/dock_state.dart).

### 14.6 Quellen-Navigation (S-4)

`registerQuellenHooks()` (features/quellen/quellen.dart, idempotent — läuft beim Boot über
`wireAppSlots`) · `showStoreModal(context)` (🗄 der Topbar) · `showLinkEditModal(context, srcId:,
onDone:)` · `showImportFilesModal` / `showNewSourceModal` — alle context-only. Fußnoten-Modal
(`showFootnoteModal`) navigiert selbst nach `/quellen/:id` bzw. `#/studio/<sec>/<modus>` und nutzt
seit Gate 1 auch die Marks-Stufe der Levels-Kaskade. `QuellenGptHooks.magicBar` bleibt der
K-3-Andockpunkt; `buildCmdkItems` der K-4-Punkt (§11).

---

## 15. Welle-2-Anker (Gate 2) — Wissen, Projekt/Hilfe, KI-Schicht, Doc/Print

Stand Gate 2: `flutter analyze` 0 Issues · `flutter test` 371 grün · `flutter build web --release` ✓.
Alle Welle-0-„im Bau“-Reste sind aus dem Produktpfad entfernt (`PlaceholderPage` gelöscht,
Topbar-Popovers echt). Neue Slots/Hooks weiterhin in `lib/app_wiring.dart` andocken.

### 15.1 Wissen-Welt (K-1, `features/wissen/` — kein Barrel, Direkt-Importe)

* **Route:** `#/analyse/:tab/:arg` → `WissenScreen` → `WissenPage(tab, arg)`; 8 Tabs in 3 Clustern
  (Keys `buch, modus, instanzen, ueberblick, kapitel, fazit, kennzahlen, wuerdigung`; Default
  `ueberblick`), eigene blaue Farbwelt über `t.wissen/wissenInk/wissenSoft/wissenLine`.
* **Notebook (Erklärbuch):** `notebookStoreProvider` (keepAlive; `Notebook.get/set`-Pendant, KV
  `notebook`, leer ⇒ `null`) · `erklaerbuchSourceProvider → ErklaerbuchSource{src, own, hasBuiltin}`
  (Kaskade eigenes Buch > `runtime.erklaerbuch` > `notebookStarter(titel)`) ·
  `notebookDatasetProvider` (echte Zahlen der Arbeit, `Notebook.dataset`) ·
  `notebookPromptProvider : Future<String>` (🤖-Generier-Prompt — K-3-`buch.build` watcht ihn;
  bis der keepAlive-Provider warm ist, ist der Prompt leer und das Preis-Label zieht reaktiv nach).
* **Renderer:** `notebook/notebook_model.dart` (`NbBlock`-Parser) + `nb_cell.dart`/`nb_markdown.dart`
  (alle Blocktypen; E4: js/py-Zellen werden DARGESTELLT, nicht ausgeführt) · `math/math_render.dart`.
* **Chart-Engine (CustomPainter, E11):** `charts/chart_common.dart` (`ChartCanvas` + `ChartHit` +
  `vizTipContent` — VizTip-Anbindung) · `NbChartSpec/NbChartSeries` + `nb_chart.dart` (7 Typen) ·
  `BarHChart` · `Timeline` · `FazitGraphChart` (Bézier+bipartit) · `KapitelFluss`.
* **Sonstiges:** `wissenLensProvider` (`WissenLens.set`, KV `wissenLens`) · `wissenStatsProvider`
  (`DATA_META.stats`; fehlend ⇒ `ThesisRuntime.computeStats` deterministisch nachgerechnet) ·
  Analysemodus `analysemodus/analysemodus_tab.dart` (Route `modus/<kapitel>`).

### 15.2 Projekt-Welt + Hilfe (K-2, Barrel `features/projekt/projekt.dart`)

* **works-pop gefüllt:** `_WorksPopover` der Topbar rendert `WorksMenuCard(onDismiss:)`
  (`projektArbeitenCard`-Pendant; ●/○-Aktivieren = `projectBootProvider.notifier.activateProject`
  = E8-Reboot, 🤖 Gesamt-Prompt, ⭱ Analysen, ⭳ Export, 🗑 Tombstone-Löschen, ⭱ Arbeit-Import
  mit Drei-Wege-Confirm). `worksListProvider` liefert die Liste.
* **Modals:** `showNeueArbeitModal` (Live-Parse 450 ms via `TexParse`) ·
  `showImportAnalysenModal` (11-Stufen-Mapping `repo.applyGeneratedFile`, Registry zuletzt;
  „Fertig“ auf der AKTIVEN Arbeit ⇒ `projectBootProvider.notifier.reboot()`).
* **Aktionen ohne UI:** `createFromTex(...)` (Record projects.js:107-113, id `p-<slug30>-<rand4>`) ·
  `applyRegistry(...)` · `isoNowUtc()` · `masterPrompt()` / `masterPromptWithTex(...)`
  (zeichengenau; K-3 nutzt beides für „alles kochen“).
* **Dashboard/Setup:** `ProjektPage` (Statkacheln, Kapitel-Fortschritt mit `LvlBar`,
  Quellen-Setup-Karte mit Inline-`AssignPanel` (S-1) + „⭳ Alle laden“-Sequenz,
  Referenzierungsdurchläufe → `showDurchlaufModal` (S-4) — dort dockt die K-3-Magic-Bar an).
  `projektDetectedPdfsProvider` (countPdfs-Pendant über `FileStore.changes`).
* **Hilfe (`features/hilfe/`):** 5 Karten wortwörtlich; technisch Überholtes je Stelle
  kommentiert angepasst (E3/E4/E5/E6/E7).

### 15.3 KI-Schicht (K-3, Barrel `features/ai/ai.dart`)

* **gpt-pop gefüllt:** `_GptPopover` der Topbar rendert `GptHubCard(location:, onDismiss:)`
  (`Enhance.hub`); `aiHubCtx` mappt Route→Flow-Kontext (studioLast-Fallback).
* **Flows:** `buildAiFlows(container, ctx) → Map<String, AiFlow>` — 7 Flows
  (`all/buch/marks/conn/inst/quellen/style`) mit `build/run/check/reference/done/stat/statOn`;
  Checker/Referenzen STRUKTURIERT (`AiCheckResult`, `AiReference`, `RichBit`) statt HTML.
  Import-Ziele: `marksExtra`/`paraDock` → `StudioKv`, `kiConnections`/`resolutions` → `QuellenKv`,
  `notebook` → `NotebookStore`. W8/E9: Quellen-Prompt projektabhängig via `gptPromptForSource` (S-4).
* **Client:** `claudeClientProvider` / `ClaudeClient.run` (SSE selbst geparst, Fehler-Map wörtlich,
  Demo-Modus wortweise 14 ms) · `countTokens` · `AiCancelToken`/`AiAbortException` · `claudeClean` ·
  `kClaudeModels` + Preise · `ClaudeCfgStore`/`EnhCfgStore` (globale KV-Keys `claudeCfg`/`enhCfg`;
  E10: Key im Klartext, secure-storage als dokumentierte Ausbaustufe).
* **UI:** `openEnhancePanel(context)` (Werkbank, rechts einfahrend; Schließen bricht ✦-Lauf ab) ·
  `AiMagicDock`/`AiRunHandle` (Ein-Klick-Kochen, Token-Live-Zähler, ✓-Finale 1250 ms,
  Import-Fehler ⇒ nahtlos `showAiPasteModal` mit prefill+autocheck) · `showAiPasteModal` /
  `showAiInfoModal` / `showAiStandModal` · `showClaudeConfigModal` · `AiMagicBar`
  (füllt `QuellenGptHooks.magicBar` — streamt ins Antwortfeld, importiert bewusst NICHT selbst;
  der Nutzer klickt ⭱, der Format-Checker meldet sich vorher).
* **Anker:** `wireAiHooks()` (aus `wireAppSlots()`) setzt `QuellenGptHooks.magicBar` und
  `InstanzGenerateHook.recompile/afterCreate` (neuer Anker in
  `features/studio/views/instanz_edit_modal.dart` — Fallback ohne Hook bleibt der ⧉-Prompt-Dialog).
  `aiViewGenerate` = viewGenerate-Port.

### 15.4 Doc/Print + cmdk (K-4, `features/doc/` + `core/shell/cmdk.dart`)

* `buildThesisPdfBytes({...}) → Future<Uint8List>` (Titelseite, Kapitel-Seitenläufe,
  Endnoten je Kapitel statt Seitenfußnoten — dokumentierte Abweichung im Datei-Kopf) ·
  `DocPrintFonts` (PT Serif + Inter aus Bundle-Assets) · `isPdfEmbeddableImage` ·
  `toPdfEmbeddableImage` (WebP→PNG) · `loadDocPrintImages` (Asset → FigStore-Kaskade) ·
  `showDocPrintProgress → DocPrintProgressHandle{step, close}`. `DocScreen._print` orchestriert
  Dialog → Bilder → Bytes → `Printing.layoutPdf`; Fehlerpfad „🖨 Drucken fehlgeschlagen“.
* `buildCmdkItems` final gegen app.js:150-168 fixiert (8 Ansichten + Abschnitte + Quellen,
  contains-Filter max 40) — per Test `test/features/doc/cmdk_items_test.dart` abgesichert.

### 15.5 Gate-2-Querschnitts-Fixes (Eigner-übergreifend, dokumentiert)

1. **`core/widgets/notice.dart`:** `Notice` wickelt seine stretch-Row jetzt INTERN in
   `IntrinsicHeight` — kein „infinite height“-Wurf mehr in Columns/ScrollViews; die
   Wrapper an den Nutzstellen (K-2) wurden entfernt. API unverändert.
2. **`features/studio/layout/studio_state.dart` (`StudioKv`):** Live-Kohärenz wie `QuellenKv` —
   jeder Studio-Key wird per `kv.watchJson` abonniert (Deep-Equality-Guard gegen Echo-Rebuilds);
   zusätzlich lädt der Schnappschuss jetzt `kiConnections` (⤳ side_graph zeigte KI-importierte
   Kanten sonst nie ohne Reboot; Fremd-Writes der Quellen-Welt — ✦ Durchlauf → `resolutions`,
   Beleg-Prüfung der Bibliothek → `belegLevels` — erreichen das warme Studio jetzt sofort).
3. **`core/shell/placeholder_page.dart` GELÖSCHT** (toter Code, keine Referenzen mehr).
