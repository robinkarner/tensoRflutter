/// Die einklappbaren Sektionen des Detailpanels (`details.libd-sec`) —
/// Ports aus `renderLibDetail` (views_quellen.js:446-638):
/// Referenzierungsvorschläge (nur custom) · Fundstellen-Register (nur
/// Rechtsquellen) · Zitierstellen (mit Level-Eskalation + Sprung ins
/// Studio) · Text-Erwähnungen (Status-Workflow ✓/✗/↺) · Text der Quelle.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/accordion.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../domain/domain.dart';
import '../state/quellen_kv.dart';
import 'provision_register.dart';

/// Sektions-Hülle: `details.libd-sec` = Accordion in der section-Variante.
class LibdSection extends StatelessWidget {
  const LibdSection({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.initiallyOpen = false,
  });

  final String title;
  final Widget body;
  final Widget? trailing;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Accordion(
      variant: AccordionVariant.section,
      initiallyOpen: initiallyOpen,
      title: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(title)),
        if (trailing != null) ...[const SizedBox(width: 7), trailing!],
      ]),
      body: body,
    );
  }
}

// ---------------------------------------------------------------------------
// Referenzierungsvorschläge (nur custom, aus 🤖 Ergänzung)
// ---------------------------------------------------------------------------

/// `vermuteteStellen` einer manuellen Quelle (js:520-530). Die Daten kommen
/// ROH aus dem customSources-Store (das Source-Modell trägt sie nicht).
class VermuteteStellenSection extends StatelessWidget {
  const VermuteteStellenSection({super.key, required this.stellen});

  /// Rohe Einträge {claim, fundstelle, suchHinweis, abschnittVermutet}.
  final List<Map<String, Object?>> stellen;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return LibdSection(
      title: 'Referenzierungsvorschläge',
      trailing: AppChip(
          label: '✦ ${stellen.length}', variant: AppChipVariant.ki, mini: true),
      initiallyOpen: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final v in stellen)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('✦',
                  style: AppTextStyles.mono.copyWith(fontSize: 11, color: t.ki)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${v['claim'] ?? ''}',
                      style: AppTextStyles.small.copyWith(color: t.ink)),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if ('${v['abschnittVermutet'] ?? ''}'.isNotEmpty) ...[
                        Text('passt zu',
                            style: AppTextStyles.small.copyWith(color: t.muted)),
                        _StudioLink(sectionId: '${v['abschnittVermutet']}'),
                        Text('·', style: AppTextStyles.small.copyWith(color: t.muted)),
                      ],
                      if ('${v['fundstelle'] ?? ''}'.isNotEmpty)
                        _Vermutet(fundstelle: '${v['fundstelle']}'),
                    ],
                  ),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// „vermutet **`<fundstelle>`**" (`.br-vermutet`).
class _Vermutet extends StatelessWidget {
  const _Vermutet({required this.fundstelle});

  final String fundstelle;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'vermutet '),
        TextSpan(
            text: fundstelle, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
      style: AppTextStyles.small.copyWith(color: t.muted),
    );
  }
}

class _StudioLink extends StatelessWidget {
  const _StudioLink({required this.sectionId});

  final String sectionId;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go(Routes.studioPath(sec: sectionId)),
        child: Text(sectionId,
            style: AppTextStyles.small.copyWith(color: t.accentInk)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fundstellen-Register (Rechtsquellen)
// ---------------------------------------------------------------------------

class RegisterSection extends StatelessWidget {
  const RegisterSection({super.key, required this.source});

  final Source source;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final provs = provisionRegister(source);
    return LibdSection(
      title: 'Fundstellen-Register',
      trailing: AppChip(
          label: '${provs.length} ${source.kind == 'recht-at' ? '§§' : 'Artikel'}'),
      initiallyOpen: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Welche Bestimmungen dieser Rechtsquelle die Arbeit wo verwendet '
            '— abgeleitet aus den Fußnotentexten.',
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
        ),
        if (provs.isEmpty)
          Text('Keine Art/§-Angaben in den Fußnoten gefunden.',
              style: AppTextStyles.small.copyWith(color: t.muted))
        else
          for (final pr in provs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 74),
                  child: Text(
                    pr.key,
                    style: AppTextStyles.mono
                        .copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: t.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 3, children: [
                    for (final c in pr.cites)
                      Tooltip(
                        message:
                            'Fußnote ${c.footnote} in Abschnitt ${c.sectionId}',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => context.go(Routes.studioPath(
                                sec: c.sectionId, modus: StudioModes.pruefen)),
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: c.sectionId),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.top,
                                  child: Transform.translate(
                                    offset: const Offset(0, -2),
                                    child: Text('${c.footnote}',
                                        style: AppTextStyles.mono.copyWith(
                                            fontSize: 8.5, color: t.accentInk)),
                                  ),
                                ),
                              ]),
                              style: AppTextStyles.small
                                  .copyWith(fontSize: 12.5, color: t.accentInk),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: 8),
                Text('${pr.cites.length}×',
                    style: AppTextStyles.mono.copyWith(fontSize: 11, color: t.muted)),
              ]),
            ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Zitierstellen
// ---------------------------------------------------------------------------

class ZitierstellenSection extends StatelessWidget {
  const ZitierstellenSection({
    super.key,
    required this.source,
    required this.levels,
  });

  final Source source;
  final Levels levels;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return LibdSection(
      title: 'Zitierstellen',
      trailing: AppChip(label: '${source.stellen.length}'),
      initiallyOpen: true,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final c in source.stellen) _citeRow(context, t, c),
      ]),
    );
  }

  /// Eine `.cite-row` (js:562-576): Status-Punkt + [fn] · „→ Studio" ·
  /// Claim/Fußnotentext · Eskalation (Zitat ab L2, Fundstellen-Chip ab L3).
  Widget _citeRow(BuildContext context, BookClothTokens t, Stelle c) {
    final inf = levels.info(c.footnote);
    final farbKey = inf.farbe ?? levels.farbeFor(source.id, c.footnote);
    final seite = inf.seite;
    final zitat = inf.zitat ?? '';
    final zitatShort =
        zitat.length > 120 ? '${zitat.substring(0, 120)}…' : zitat;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // .num: Levels.dot + [fn]
        Row(mainAxisSize: MainAxisSize.min, children: [
          LevelDot(inf.level, ringColor: BookClothTokens.markFarbe(farbKey)),
          const SizedBox(width: 5),
          Text('[${c.footnote}]',
              style: AppTextStyles.mono.copyWith(fontSize: 11, color: t.accentInk)),
        ]),
        const SizedBox(width: 8),
        AppButton(
          small: true,
          tooltip: 'Diese Zitierstelle im Studio öffnen (Abschnitt '
              '${c.sectionId}${c.paragraphId.isNotEmpty ? ' · Absatz ${c.paragraphId}' : ''})',
          onPressed: () => context.go(Routes.studioPath(
            sec: c.sectionId,
            modus: StudioModes.pruefen,
            para: c.paragraphId.isNotEmpty ? c.paragraphId : null,
          )),
          child: const Text('→ Studio'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              c.claim.isNotEmpty ? c.claim : c.footnoteText,
              style: AppTextStyles.small.copyWith(color: t.ink),
            ),
            if (c.fundstelle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _Vermutet(fundstelle: c.fundstelle),
              ),
            if (inf.level >= 2 && zitat.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('❝ „$zitatShort“',
                    style: AppTextStyles.small.copyWith(color: t.ink2)),
              ),
            if (jsTruthy(seite) ||
                ((inf.fundstelle ?? '').isNotEmpty && inf.level >= 3))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Wrap(spacing: 4, children: [
                  if (jsTruthy(seite)) AppChip(label: 'S. $seite', mini: true),
                  if ((inf.fundstelle ?? '').isNotEmpty && inf.level >= 3)
                    AppChip(
                        label: inf.fundstelle!,
                        variant: AppChipVariant.ok,
                        mini: true),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Text-Erwähnungen
// ---------------------------------------------------------------------------

class MentionsSection extends ConsumerWidget {
  const MentionsSection({super.key, required this.srcId, required this.mentions});

  final String srcId;
  final List<Mention> mentions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    final conf = mentions
        .where((m) => m.status == 'bestaetigt' || m.status == 'beleg')
        .length;
    final offen = mentions.where((m) => m.status == 'offen').length;

    return LibdSection(
      title: 'Text-Erwähnungen',
      initiallyOpen: offen > 0,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        AppChip(
            label: '$conf bestätigt',
            variant: conf > 0 ? AppChipVariant.ok : AppChipVariant.neutral,
            mini: true),
        if (offen > 0) ...[
          const SizedBox(width: 4),
          AppChip(label: '✦ $offen offen', variant: AppChipVariant.ki, mini: true),
        ],
      ]),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Stellen, an denen diese Quelle nur über die Autorennennung im '
            'Fließtext referenziert wird — erkannt ohne KI, per Bestätigung '
            'übernommen.',
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
        ),
        for (final mt in mentions) _mentionRow(context, ref, t, mt),
      ]),
    );
  }

  Widget _mentionRow(
      BuildContext context, WidgetRef ref, BookClothTokens t, Mention mt) {
    final nCand = mt.candidates.length;
    void setStatus(String status) {
      final domain = ref.read(quellenDomainProvider);
      domain?.mentions.setStatus(mt.key, status, srcId);
    }

    final stIcon = mt.status == 'bestaetigt' || mt.status == 'beleg'
        ? '❞'
        : mt.status == 'verworfen'
            ? '·'
            : '✦';

    return Opacity(
      opacity: mt.status == 'verworfen' ? .62 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 16,
            child: Text(stIcon,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: mt.status == 'offen' ? t.ki : t.ink2,
                    fontFamilyFallback: AppFonts.fallback)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tooltip(
                  message: 'Zur Textstelle springen (Absatz ${mt.paraId})',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => context.go(Routes.studioPath(
                          sec: mt.sectionId,
                          modus: StudioModes.pruefen,
                          para: mt.paraId)),
                      child: Text('⌖ ${mt.sectionId} · ${mt.paraId}',
                          style:
                              AppTextStyles.small.copyWith(color: t.accentInk)),
                    ),
                  ),
                ),
                Text('· „${mt.snippet}“',
                    style: AppTextStyles.small.copyWith(color: t.ink)),
                if (nCand > 1 && mt.status == 'offen')
                  Tooltip(
                    message:
                        'Mehrere mögliche Quellen — Auswahl an der Textstelle',
                    child: AppChip(
                        label: '$nCand Kandidaten',
                        variant: AppChipVariant.ki,
                        mini: true),
                  ),
                if (mt.status == 'beleg')
                  Tooltip(
                    message: 'Mit Fußnote [${mt.fn}] zusammengeführt — '
                        'Text-Nennung und Fußnote zeigen auf denselben Beleg',
                    child: AppChip(
                        label: '⇒ Beleg [${mt.fn}]',
                        variant: AppChipVariant.ok,
                        mini: true),
                  ),
                if (mt.status == 'verworfen')
                  Text('(verworfen)',
                      style: AppTextStyles.small.copyWith(color: t.muted)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // .acts: offen → ✓/✗ · sonst ↺
          if (mt.status == 'offen')
            Row(mainAxisSize: MainAxisSize.min, children: [
              AppButton(
                variant: AppButtonVariant.primary,
                small: true,
                onPressed: () => setStatus('bestaetigt'),
                child: const Text('✓'),
              ),
              const SizedBox(width: 4),
              AppButton(
                small: true,
                onPressed: () => setStatus('verworfen'),
                child: const Text('✗'),
              ),
            ])
          else
            AppButton(
              small: true,
              tooltip: 'zurücksetzen',
              onPressed: () => setStatus('offen'),
              child: const Text('↺'),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text der Quelle
// ---------------------------------------------------------------------------

/// Textarea + Speichern + .txt laden (js:612-637). Der hinterlegte Text ist
/// im Splitscreen (☰ Text der Großen Ansicht, S-3) markierbar wie ein PDF —
/// Auswahl übernimmt dort das Zitat über die Satz-Offsets.
class SrcTextSection extends ConsumerStatefulWidget {
  const SrcTextSection({
    super.key,
    required this.srcId,
    required this.text,
    required this.initiallyOpen,
    required this.pickTextFile,
  });

  final String srcId;
  final String text;
  final bool initiallyOpen;

  /// .txt-Datei wählen und lesen (Picker lebt beim Aufrufer).
  final Future<String?> Function() pickTextFile;

  @override
  ConsumerState<SrcTextSection> createState() => _SrcTextSectionState();
}

class _SrcTextSectionState extends ConsumerState<SrcTextSection> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.text);
  String _msg = '';
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save(String value) async {
    await ref.read(kvStoreProvider).setSrcTextRaw(widget.srcId, value);
    if (!mounted) return;
    setState(() => _msg = '✓ gespeichert');
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _msg = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final has = widget.text.isNotEmpty;

    return LibdSection(
      title: 'Text der Quelle',
      initiallyOpen: widget.initiallyOpen,
      trailing: has
          ? AppChip(
              label: '✓ ${(widget.text.length / 1000).toStringAsFixed(1)}k Zeichen',
              variant: AppChipVariant.ok,
              mini: true)
          : const AppChip(label: 'markierbare Alternative zum PDF', mini: true),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(
                text: 'Der hinterlegte Text ist im Splitscreen unter '),
            const TextSpan(
                text: '☰ Text', style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(
                text: ' markierbar wie ein PDF — praktisch für Gesetzestexte '
                    '(EUR-Lex/RIS „Text kopieren“) und Online-Quellen.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          minLines: 4,
          maxLines: 14,
          style: AppTextStyles.mono.copyWith(fontSize: 12.5, color: t.ink),
          decoration: const InputDecoration(hintText: 'Quellentext einfügen …'),
        ),
        const SizedBox(height: 6),
        Row(children: [
          AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: () => unawaited(_save(_ctrl.text)),
            child: const Text('Speichern'),
          ),
          const SizedBox(width: 6),
          AppButton(
            small: true,
            onPressed: () async {
              final text = await widget.pickTextFile();
              if (text == null) return;
              _ctrl.text = text;
              await _save(text);
            },
            child: const Text('.txt laden'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_msg, style: AppTextStyles.small.copyWith(color: t.muted)),
          ),
        ]),
      ]),
    );
  }
}

/// `U.setSrcText`-Pendant mit Roh-Semantik der Bibliothek (leer ⇒ Eintrag
/// fliegt aus der Map) — bewusst hier statt über die pdf-Extension, damit
/// die Quellen-Welt nicht von deren Trim-Detail abhängt.
extension on KvStore {
  Future<void> setSrcTextRaw(String srcId, String text) async {
    final all = Map<String, dynamic>.from(await getMap(KvKeys.srcTexts));
    if (text.trim().isNotEmpty) {
      all[srcId] = text;
    } else {
      all.remove(srcId);
    }
    await setJson(KvKeys.srcTexts, all);
  }
}
