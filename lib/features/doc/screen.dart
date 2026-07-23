/// ▤ `#/doc` — die GANZE Arbeit als EIN fortlaufendes, kompiliertes Dokument
/// (Port von `renderDoc`, views_studio.js:448-490): dieselbe Darstellung wie
/// der Lesen-Modus (Serif-Satz, Markierungs-/View-Einstellungen inklusive),
/// darüber die Aktionsleiste „⭳ Ganzes LaTeX (.tex)“ · „🖨 Als PDF drucken“
/// (printing-Paket) · „◱ LaTeX ansehen“ und die Views-/Instanz-Leiste.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/modal.dart';
import '../../data/bundles/indexes.dart';
import '../../data/models/models.dart';
import '../../data/repos/fig_store.dart';
import '../studio/layout/studio_state.dart';
import '../studio/lesen/lesen_mode.dart' show LesenSection;
import '../studio/views/instanz_bar.dart';
import '../studio/views/wiring.dart';
import 'doc_images.dart';
import 'doc_print.dart';
import 'latex_modal.dart';
import 'print_progress.dart';
import '../studio/editor/tex_save.dart';

class DocScreen extends ConsumerStatefulWidget {
  const DocScreen({super.key});

  @override
  ConsumerState<DocScreen> createState() => _DocScreenState();
}

class _DocScreenState extends ConsumerState<DocScreen> {
  @override
  void initState() {
    super.initState();
    // Defensive Selbst-Verdrahtung — läuft regulär schon beim App-Start
    // über `wireAppSlots()` (lib/app_wiring.dart); hier nur als idempotentes
    // Sicherheitsnetz für Tests, die den Screen isoliert pumpen.
    wireStudioS3();
  }

  /// `Editor.fullDocument()` — komplettes LaTeX inkl. lokaler Änderungen.
  /// (`meta.abstract` des Originals existiert in den Realdaten nie —
  /// TexParse legt Abstract/Kurzfassung als Front-Kapitel ab, daher kein
  /// abstract-Argument.)
  String? _fullTex() => ref.read(studioDomainProvider)?.editor.fullDocument();

  /// „🖨 Als PDF drucken": Schriften + Bilder laden, Dokument setzen
  /// (Fortschritts-Dialog), dann in den System-Druckdialog reichen.
  Future<void> _print(Thesis thesis) async {
    final fnTexts = {
      for (final e in ref.read(fnIndexProvider).entries) e.key: e.value.text,
    };
    final figures =
        ref.read(activeRuntimeProvider)?.figures ?? FiguresManifest.empty;
    final figStore = ref.read(figStoreProvider).value;

    final progress = showDocPrintProgress(context);
    try {
      progress.step('Bilder einbetten …');
      final images = await loadDocPrintImages(
        figures: figures,
        figStore: figStore,
        onProgress: (geladen, gesamt) =>
            progress.step('Bilder einbetten … ($geladen/$gesamt)'),
      );
      final bytes = await buildThesisPdfBytes(
        thesis: thesis,
        fnTexts: fnTexts,
        figures: figures,
        images: images,
        onProgress: progress.step,
      );
      progress.close();
      await Printing.layoutPdf(
        name: thesis.meta.title.isEmpty ? 'thesis' : thesis.meta.title,
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      progress.close();
      if (!mounted) return;
      await showAppModal<void>(
        context,
        title: const Text('🖨 Drucken fehlgeschlagen'),
        body: Text('Das PDF konnte nicht erzeugt werden: $e'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final thesis = ref.watch(effectiveThesisProvider);
    final ordered = ref.watch(orderedUnitsProvider);

    if (thesis == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('Lade …',
              style: AppTextStyles.small.copyWith(color: t.muted)),
        ),
      );
    }

    final meta = thesis.meta;
    final subMeta = [
      if (meta.subtitle.isNotEmpty) meta.subtitle,
      if (meta.author.isNotEmpty) meta.author,
      if (meta.university.isNotEmpty) meta.university,
      if (meta.date.isNotEmpty) meta.date,
    ].join(' · ');

    // Alle Abschnitte mit Absätzen in Dokumentreihenfolge (DFS je Kapitel).
    final sections = <(Unit, Chapter)>[];
    void walk(List<Unit> units, Chapter ch) {
      for (final u in units) {
        if (u.paragraphs.isNotEmpty) sections.add((u, ch));
        walk(u.children, ch);
      }
    }

    for (final ch in thesis.chapters) {
      walk(ch.sections, ch);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- page-head ------------------------------------------------------
        Text(meta.title.isEmpty ? 'PDF Dokument' : meta.title,
            style: AppTextStyles.h1.copyWith(color: t.ink)),
        const SizedBox(height: 4),
        Text(
          '$subMeta — die ganze Arbeit als ein Dokument: komplettes LaTeX '
          'generieren oder direkt als PDF drucken.',
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 20),
        // ---- doc-actions ----------------------------------------------------
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton(
              small: true,
              variant: AppButtonVariant.primary,
              tooltip:
                  'Das komplette, kompilierbare LaTeX-Dokument aller Abschnitte '
                  'generieren und herunterladen (lokale Änderungen eingerechnet)',
              onPressed: () {
                final tex = _fullTex();
                if (tex != null) saveTexFile('thesis.tex', tex);
              },
              child: const Text('⭳ Ganzes LaTeX (.tex)'),
            ),
            AppButton(
              small: true,
              tooltip:
                  'Diese Ansicht als PDF drucken/speichern (System-Druckdialog '
                  '→ „Als PDF speichern“)',
              onPressed: () => _print(thesis),
              child: const Text('🖨 Als PDF drucken'),
            ),
            AppButton(
              small: true,
              tooltip: 'Das generierte LaTeX ansehen',
              onPressed: () {
                final tex = _fullTex();
                if (tex != null) showLatexViewModal(context, tex);
              },
              child: const Text('◱ LaTeX ansehen'),
            ),
            Text(
              'Kompilierbares LaTeX (report-Klasse, Präambel + Titel + alle '
              'Abschnitte) — oder direkt PDF.',
              style: AppTextStyles.small.copyWith(color: t.muted),
            ),
          ],
        ),
        // ---- Views-Leiste + lesen-doc --------------------------------------
        if (ordered.isNotEmpty) InstanzBar(sectionId: ordered.first),
        const SizedBox(height: 8),
        for (final (u, ch) in sections) LesenSection(unit: u, chapter: ch),
      ],
    );
  }
}
