/// Notebook-Zustand: das eigene Erklärbuch (KV-Key `notebook`, projekt-
/// gescoped), die Quellen-Kaskade und das Datenpaket der Rechenzellen.
///
/// Kaskade (views_analyse.js:58-62, exakt): eigenes Buch (`Notebook.get()`)
/// > eingebautes Buch der Arbeit (`PROJECT_ERKLAERBUCH` =
/// `runtime.erklaerbuch`) > Starter-Buch. `set(null)`/Leerstring löscht das
/// eigene Buch (notebook.js:168).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../domain/domain.dart';
import '../../studio/layout/studio_state.dart';

part 'notebook_state.g.dart';

// ---------------------------------------------------------------------------
// Eigenes Buch (KV `notebook`)
// ---------------------------------------------------------------------------

/// `Notebook.get()`/`Notebook.set(md)` — null = kein eigenes Buch.
@Riverpod(keepAlive: true)
class NotebookStore extends _$NotebookStore {
  @override
  Future<String?> build() async {
    // Projektwechsel lädt das Buch des neuen Scopes.
    ref.watch(activeRuntimeProvider);
    final v = await ref.watch(kvStoreProvider).getJson(KvKeys.notebook);
    return (v is String && v.trim().isNotEmpty) ? v : null;
  }

  /// Speichert [md]; leer/blank löscht (Original speichert `null`).
  void set(String? md) {
    final value = (md != null && md.trim().isNotEmpty) ? md : null;
    state = AsyncData(value);
    final kv = ref.read(kvStoreProvider);
    if (value == null) {
      kv.remove(KvKeys.notebook);
    } else {
      kv.setJson(KvKeys.notebook, value);
    }
  }
}

// ---------------------------------------------------------------------------
// Effektive Buch-Quelle
// ---------------------------------------------------------------------------

/// Auflösung der Erklärbuch-Kaskade fürs Rendern und die nb-bar.
class ErklaerbuchSource {
  final String src;

  /// Eigenes Buch aktiv (→ ↺-Reset-Knopf sichtbar).
  final bool own;

  /// Die Arbeit bringt ein eingebautes Buch mit.
  final bool hasBuiltin;

  const ErklaerbuchSource({
    required this.src,
    required this.own,
    required this.hasBuiltin,
  });
}

@Riverpod(keepAlive: true)
ErklaerbuchSource erklaerbuchSource(Ref ref) {
  final stored = ref.watch(notebookStoreProvider).value;
  final builtin = ref.watch(activeRuntimeProvider)?.erklaerbuch;
  final titel = ref.watch(activeRuntimeProvider)?.thesis.meta.title;
  return ErklaerbuchSource(
    src: stored ?? builtin ?? notebookStarter(titel),
    own: stored != null,
    hasBuiltin: builtin != null,
  );
}

// ---------------------------------------------------------------------------
// Datenpaket (`Notebook.dataset`, notebook.js:414-441)
// ---------------------------------------------------------------------------

/// Echte Zahlen der aktiven Arbeit — Grundlage der Rechenzellen (E4: nur
/// noch fürs 🤖-Prompt-Paket) und des Generier-Prompts.
@Riverpod(keepAlive: true)
Future<Map<String, Object?>> notebookDataset(Ref ref) async {
  final runtime = ref.watch(activeRuntimeProvider);
  final thesis = ref.watch(effectiveThesisProvider);
  final domain = ref.watch(studioDomainProvider);
  if (runtime == null || thesis == null || domain == null) return const {};

  // Kapitel-Kennzahlen (Abschnitte mit Absätzen, Absätze, Fußnoten).
  final kapitel = <Map<String, Object?>>[];
  for (final ch in thesis.chapters) {
    var abs = 0, par = 0, fns = 0;
    void walk(List<Unit> units) {
      for (final u in units) {
        if (u.paragraphs.isNotEmpty) {
          abs++;
          par += u.paragraphs.length;
          for (final p in u.paragraphs) {
            fns += p.footnotes.length;
          }
        }
        walk(u.children);
      }
    }

    walk(ch.sections);
    kapitel.add({
      'num': ch.num,
      'titel': ch.title,
      'abschnitte': abs,
      'absaetze': par,
      'fussnoten': fns,
    });
  }

  final quellen = [
    for (final s in runtime.sources)
      {
        'id': s.id,
        'titel': s.title,
        'kurz': domain.ctx.srcShort(s.id),
        'typ': s.kind,
        'jahr': s.year,
        'zitierstellen': s.citations.length,
      },
  ];

  final status = domain.levels.countsFor(domain.levels.allNums());

  // Connections mit KI-Kanten aus dem Store (`kiConnections` liegt nicht im
  // Studio-Schnappschuss — hier direkt aus der KV-Schicht lesen).
  final kiRaw = await ref.watch(kvStoreProvider).getJson(KvKeys.kiConnections);
  final conns = Connections(
    domain.ctx,
    MemoryDomainStore({KvKeys.kiConnections: kiRaw}),
  ).all();
  final connTypes = <String, int>{};
  for (final c in conns) {
    connTypes[c.typ] = (connTypes[c.typ] ?? 0) + 1;
  }

  return {
    'arbeit': {
      'titel': thesis.meta.title,
      'autor': thesis.meta.author,
      'universitaet': thesis.meta.university,
    },
    'kapitel': kapitel,
    'quellen': quellen,
    'belegStatus': {
      'offen': status.l0,
      'vermutet': status.l1,
      'original': status.l2,
      'belegt': status.l3,
      'gesamt': status.total,
    },
    'verbindungen': {'gesamt': conns.length, 'nachTyp': connTypes},
    'abbildungen': [
      for (final f in runtime.figures.figuren) {'id': f.id, 'titel': f.titel},
    ],
  };
}

// ---------------------------------------------------------------------------
// Starter-Buch (`Notebook.starter`, notebook.js:570-649 — wortwörtlich)
// ---------------------------------------------------------------------------

/// Rechnet im Original live mit den Daten der aktiven Arbeit; die js-/py-
/// Zellen bleiben als Referenz-Content erhalten (E4: rendern statt ausführen).
String notebookStarter(String? metaTitle) {
  final titel = ((metaTitle == null || metaTitle.isEmpty) ? 'die Arbeit' : metaTitle);
  final short = titel.length > 60 ? titel.substring(0, 60) : titel;
  return '# Erklärbuch — $short\n'
      '\n'
      'Dieses Dokument ist das **Erklärbuch** der aktiven Arbeit: Markdown als oberste Ebene,\n'
      'alles Weitere eingebettet — Diagramme, Tabellen, Mathematik, LaTeX (derselbe Interpreter\n'
      'wie die Arbeit), Abbildungen, Textpassagen und Rechenzellen (js sofort, Python auf Abruf).\n'
      '**✎ Bearbeiten** öffnet den Quelltext, **🤖 Prompt** lässt ein KI-Modell (Opus 4.8+)\n'
      'ein vollständiges Buch zu dieser Arbeit erzeugen.\n'
      '\n'
      '## Belegstand — live berechnet\n'
      '\n'
      '''```js auto
const st = data.belegStatus;
chart({ type: 'donut', title: 'Belegstatus aller ' + st.gesamt + ' Zitierstellen',
  labels: ['belegt', 'Original', 'vermutet', 'offen'],
  series: [{ values: [st.belegt, st.original, st.vermutet, st.offen] }] });
```

```js auto
chart({ type: 'bar', title: 'Fußnoten je Kapitel',
  labels: data.kapitel.map(k => k.num + ' ' + k.titel.slice(0, 14)),
  series: [{ name: 'Fußnoten', values: data.kapitel.map(k => k.fussnoten) }] });
```

## Quellenmix

```js auto
const byTyp = {};
for (const q of data.quellen) byTyp[q.typ] = (byTyp[q.typ] || 0) + 1;
chart({ type: 'barh', title: 'Quellen nach Typ',
  labels: Object.keys(byTyp), series: [{ values: Object.values(byTyp) }] });
const top = [...data.quellen].sort((a, b) => b.zitierstellen - a.zitierstellen).slice(0, 8);
table([['Quelle', 'Typ', 'Jahr', 'Zitierstellen'],
  ...top.map(q => [q.kurz, q.typ, q.jahr ?? '—', q.zitierstellen])], { sum: false });
```

## Ein wenig Statistik

'''
      r'Die mittlere Beleg-Dichte je Kapitel ($\bar{x}$) und ihre Streuung ($s$):'
      '\n\n'
      r'''$$
\bar{x} = \frac{1}{n} \sum_{i=1}^{n} x_i \qquad
s = \sqrt{\frac{1}{n-1} \sum_{i=1}^{n} (x_i - \bar{x})^2}
$$

```js auto
const xs = data.kapitel.map(k => k.fussnoten);
const n = xs.length, mean = xs.reduce((a, b) => a + b, 0) / n;
const sd = Math.sqrt(xs.reduce((a, x) => a + (x - mean) ** 2, 0) / Math.max(1, n - 1));
print('Kapitel:', n, '· Fußnoten gesamt:', xs.reduce((a, b) => a + b, 0));
print('Ø je Kapitel:', mean.toFixed(1), '· Standardabweichung:', sd.toFixed(1));
```

## LaTeX — derselbe Interpreter wie die Arbeit

```latex
\section{Eingebettetes LaTeX}

Dieser Block läuft durch \textbf{denselben} Interpreter wie der Editor der
Arbeit\footnote{Editor.preview / TexParse — ein Transformer für alles.} —
inklusive \enquote{Anführungen} und §-Zeichen (\S 22).
```

## Python (auf Abruf — ▶ drücken)

```py
# Beim ersten ▶ lädt die Python-Umgebung (Pyodide) einmalig vom CDN.
# numpy/pandas/matplotlib/scikit-learn werden bei Bedarf automatisch geladen.
import statistics
fn = [k['fussnoten'] for k in data['kapitel']]
print('Median Fußnoten/Kapitel:', statistics.median(fn))
chart({ 'type': 'line', 'title': 'Fußnoten je Kapitel (aus Python)',
  'labels': [str(k['num']) for k in data['kapitel']],
  'series': [{ 'name': 'Fußnoten', 'values': fn }] })
```

> **Weiter:** ```figure <id>``` bettet Abbildungen der Arbeit ein, ```include <abschnitt>```
> Textpassagen — alle Baustein-Typen stehen in der Referenz (docs/ERKLAERBUCH.md).
''';
}
