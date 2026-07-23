/// Views-/Instanzen-Prompt — Port von `texMaterials`/`instanzPrompt`/
/// `instanzPromptFor` (views_studio.js:2351-2358, 2484-2522). Reine
/// String-Logik: der globale KI-Prompt „Text-Views × alle Absätze der
/// Arbeit“, wahlweise für ALLE Text-Views oder eine einzelne (↻ Recompile).
///
/// K-3 (AI-Schicht) nutzt denselben Prompt für die Magic-Generierung;
/// hier dient er dem ⧉-Kopieren-Pfad („ohne Zugang“).
library;

import '../../../data/models/models.dart';
import '../../../domain/domain_context.dart';
import '../layout/dock_state.dart';

/// Σ-LaTeX-Material einer Quelle (`srcExtras`, kind `tex`).
class TexMaterial {
  final String srcId;
  final String name;
  final String text;

  const TexMaterial({required this.srcId, required this.name, required this.text});
}

/// Alle Σ-Materialien aus dem `srcExtras`-Schnappschuss (:2351-2358).
List<TexMaterial> texMaterialsFrom(Object? srcExtrasRaw) {
  final out = <TexMaterial>[];
  if (srcExtrasRaw is! Map) return out;
  for (final e in srcExtrasRaw.entries) {
    final list = e.value;
    if (list is! List) continue;
    for (final x in list) {
      if (x is Map && x['kind'] == 'tex' && x['text'] is String &&
          (x['text'] as String).isNotEmpty) {
        out.add(TexMaterial(
          srcId: '${e.key}',
          name: x['name'] is String && (x['name'] as String).isNotEmpty
              ? x['name'] as String
              : 'LaTeX',
          text: x['text'] as String,
        ));
      }
    }
  }
  return out;
}

/// Der globale Prompt für die übergebenen Views (:2485-2522, Texte wörtlich).
String instanzPromptFor(
  DomainContext ctx,
  List<DockDef> defsArg, {
  List<TexMaterial> materials = const [],
}) {
  final textDefs = [for (final d in defsArg) if (!d.special) d];
  final title = ctx.thesis?.meta.title ?? '';

  final secLines = <String>[];
  for (final id in ctx.orderedUnitIds) {
    final info = ctx.unitIndex[id];
    if (info == null) continue;
    final u = info.unit;
    final paras = [
      for (final p in u.paragraphs)
        if (p.typeEnum != ParagraphType.figure &&
            p.typeEnum != ParagraphType.table)
          p,
    ];
    if (paras.isEmpty) continue;
    final secTitle = u.isIntro ? info.chapter.title : u.title;
    secLines.add('\n== Abschnitt $id · $secTitle ==');
    for (final p in paras) {
      final body = (p.typeEnum == ParagraphType.list
              ? p.items.join('\n· ')
              : p.text)
          .replaceAll(RegExp(r'\[\^\d+\]'), '');
      secLines.add('[${p.id}]\n$body');
    }
  }

  // Σ übergeordnet verknüpftes Material der Views mit srcTex.
  final matBlocks = <String>[];
  for (final d in textDefs) {
    if (d.srcTex.isEmpty) continue;
    final mats = [for (final m in materials) if (m.srcId == d.srcTex) m];
    if (mats.isEmpty) continue;
    matBlocks.addAll([
      '',
      '=' * 60,
      'ÜBERGEORDNET VERKNÜPFTES MATERIAL für die View "${d.id}" — LaTeX der Quelle ${d.srcTex}:',
      'Nutze dieses Material als primäre Textbasis dieser View: verbinde jeden Absatz der Arbeit übergeordnet mit den passenden Stellen dieses Materials (konkret referenzieren, gern kurz zitieren).',
    ]);
    for (final m in mats) {
      matBlocks.addAll(['--- ${m.name} ---', m.text]);
    }
  }

  return [
    'Du füllst in „Thesis Studio" die Absatz-Instanzen der GANZEN Arbeit („$title").',
    'Erzeuge für JEDEN Absatz unten JEDE der folgenden Instanzen:',
    ...textDefs.map((d) =>
        '- "${d.id}" (${d.label}): ${d.desc.isNotEmpty ? d.desc : 'kurzer, hilfreicher Text je Absatz.'}${d.srcTex.isNotEmpty ? ' [Σ übergeordnet verknüpft mit Quelle ${d.srcTex} — Material unten]' : ''}'),
    '',
    'Einfacher Markdown-Text (fett/kursiv/Listen erlaubt), KEIN LaTeX. Das Original bleibt unverändert (Ground Truth).',
    '',
    'ANTWORTE NUR mit diesem JSON:',
    '{"instanzen": { ${textDefs.map((d) => '"${d.id}": { "<absatz-id>": "<markdown>", … }').join(', ')} }}',
    ...matBlocks,
    '',
    'ABSÄTZE (gesamte Arbeit):',
    ...secLines,
  ].join('\n');
}

/// Der Prompt für ALLE Text-Views (`instanzPrompt`, :2484).
String instanzPrompt(
  DomainContext ctx,
  List<DockDef> defs, {
  List<TexMaterial> materials = const [],
}) =>
    instanzPromptFor(ctx, [for (final d in defs) if (!d.special) d],
        materials: materials);
