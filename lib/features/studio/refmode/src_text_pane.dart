/// Markierbare Text-Ansicht einer Quelle im Referenzierungsmodus („☰ Text“)
/// — Port von `renderSrcTextPane` (views_studio.js:2031-2109) samt
/// `.srctext`/`.srctext-bar`/`.srctext-setup`/`.st-hl` (app.css:1302-1315):
///
///  * Ohne hinterlegten Text: Setup-Kasten „Noch kein Text hinterlegt“ mit
///    „.txt laden“ und Einfüge-Textarea + „Text übernehmen“.
///  * Mit Text: Statuszeile („aktiv: [n] — Auswahl im Text wird diesem Beleg
///    als Zitat zugeordnet“ bzw. Warnung), „✎ Text bearbeiten“ (leert den
///    Store und befüllt das Setup-Feld mit dem Backup — „bearbeiten“ heißt
///    nicht „neu tippen“), darunter der markierbare Text: erfasste Zitate
///    der Quelle sind farbig vor-markiert (`st-hl`, whitespace-tolerant,
///    nur erster Treffer), Text-Auswahl ≥ 3 Zeichen → Zitat des aktiven
///    Belegs + Auto-Save + Auswahl aufheben.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/db/kv.dart';
import '../../../domain/levels.dart';
import '../../pdf/pdf.dart';
import '../layout/css_color.dart';
import '../layout/studio_state.dart';

/// Ein farbig vor-markierter Zitat-Treffer im Quellentext.
typedef _Hit = ({int start, int end, Color color});

class SrcTextPane extends ConsumerStatefulWidget {
  const SrcTextPane({
    super.key,
    required this.srcId,
    required this.activeInfo,
    required this.onQuote,
    this.onChanged,
  });

  final String srcId;

  /// Aktiver Beleg (`refActiveInfo`) — null = „Kein Beleg aktiv“.
  final ActiveBeleg? Function() activeInfo;

  /// Auswahl im Text → Zitat dieses Belegs (Auto-Save macht der Aufrufer).
  final ValueChanged<String> onQuote;

  /// Text wurde hinterlegt/geleert (Aufrufer invalidiert seinen Befund).
  final VoidCallback? onChanged;

  @override
  ConsumerState<SrcTextPane> createState() => _SrcTextPaneState();
}

class _SrcTextPaneState extends ConsumerState<SrcTextPane> {
  String? _text; // null = lädt noch; '' = kein Text (Setup-Ansicht)
  final TextEditingController _paste = TextEditingController();

  /// Auswahl-Zwischenstand (Commit bei Pointer-Up = mouseup-Pendant).
  TextSelection? _sel;

  /// Key-Wechsel setzt die Auswahl nach der Übernahme zurück
  /// (`sel.removeAllRanges()`).
  int _selEpoch = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final text = await ref.read(kvStoreProvider).getSrcText(widget.srcId);
    if (mounted) setState(() => _text = text);
  }

  Future<void> _save(String value) async {
    await ref.read(kvStoreProvider).setSrcText(widget.srcId, value);
    if (!mounted) return;
    setState(() {
      _text = value;
      _sel = null;
      _selEpoch++;
    });
    widget.onChanged?.call();
  }

  /// „✎ Text bearbeiten“: Store leeren, Backup ins Setup-Feld (:2086-2092).
  Future<void> _startEdit() async {
    final bak = _text ?? '';
    _paste.text = bak;
    await _save('');
  }

  Future<void> _pickTxt() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      withData: true,
    );
    final bytes = res?.files.firstOrNull?.bytes;
    if (bytes == null) return;
    await _save(utf8.decode(bytes, allowMalformed: true));
  }

  /// mouseup-Pendant (:2094-2108): normalisierte Auswahl ≥ 3 Zeichen →
  /// Zitat des aktiven Belegs, Auswahl aufheben.
  void _commitSelection(String text) {
    final sel = _sel;
    if (sel == null || sel.isCollapsed) return;
    final raw = text.substring(sel.start, sel.end);
    final t = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length < 3) return;
    final a = widget.activeInfo();
    if (a == null) return; // Statuszeile zeigt die Warnung ohnehin an
    widget.onQuote(t);
    setState(() {
      _sel = null;
      _selEpoch++;
    });
    widget.onChanged?.call();
  }

  /// Erfasste Zitate dieser Quelle im Text finden (whitespace-tolerant,
  /// case-insensitiv, nur der ERSTE Treffer je Fußnote, :2056-2068).
  List<_Hit> _zitatHits(String text, StudioDomain domain) {
    final t = BookClothTokens.of(context);
    final hits = <_Hit>[];
    for (final num in domain.levels.numsForSource(widget.srcId)) {
      final inf = domain.levels.info(num);
      final zitat = inf.zitat ?? '';
      if (zitat.length < 8) continue;
      final hex = Levels.farbHex(domain.levels.farbeFor(widget.srcId, num));
      final color =
          resolveCssColor(t, hex) ?? const Color(0xFFE8C33F); // Fallback-Gelb
      final pattern = RegExp.escape(zitat).replaceAll(RegExp(r'\\?\s+'), r'\s+');
      try {
        final m = RegExp(pattern, caseSensitive: false).firstMatch(text);
        if (m != null) hits.add((start: m.start, end: m.end, color: color));
      } catch (_) {
        // Muster zu komplex — Hervorhebung ist optional.
      }
    }
    hits.sort((a, b) => a.start.compareTo(b.start));
    // Überlappungen verwerfen (der DOM-Ersatz im Original überschreibt sie
    // implizit — hier gewinnt der frühere Treffer).
    final out = <_Hit>[];
    var pos = 0;
    for (final h in hits) {
      if (h.start >= pos) {
        out.add(h);
        pos = h.end;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final text = _text;
    if (text == null) {
      return Center(
        child: Text('Lade …', style: AppTextStyles.small.copyWith(color: t.muted)),
      );
    }
    return text.isEmpty ? _setup(t) : _viewer(t, text);
  }

  // ---- Setup (kein Text hinterlegt, :2034-2053) ---------------------------

  Widget _setup(BookClothTokens t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.borderStrong),
              borderRadius: BorderRadius.circular(BookClothTokens.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Noch kein Text hinterlegt',
                    style: AppTextStyles.small.copyWith(
                        fontWeight: FontWeight.w700, color: t.ink)),
                const SizedBox(height: 6),
                Text(
                  'Quellentext (z. B. konsolidierte Gesetzesfassung, Artikeltext) '
                  'einfügen oder als .txt laden — danach ist er hier markierbar '
                  'wie ein PDF: Auswahl übernimmt das Zitat in den aktiven Beleg.',
                  style: AppTextStyles.small.copyWith(color: t.muted, height: 1.55),
                ),
                const SizedBox(height: 10),
                AppButton(
                  small: true,
                  onPressed: _pickTxt,
                  child: const Text('.txt laden'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _paste,
            maxLines: null,
            minLines: 8,
            style: AppTextStyles.small
                .copyWith(fontSize: 13, height: 1.55, color: t.ink),
            decoration: InputDecoration(
              hintText: '… oder Text hier einfügen',
              hintStyle: AppTextStyles.small.copyWith(color: t.muted),
              filled: true,
              fillColor: t.surface,
              contentPadding: const EdgeInsets.all(10),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.borderStrong),
                borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: t.accent, width: 2),
                borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AppButton(
                small: true,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  final v = _paste.text;
                  if (v.trim().isNotEmpty) _save(v);
                },
                child: const Text('Text übernehmen'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Viewer (Text vorhanden, :2056-2108) --------------------------------

  Widget _viewer(BookClothTokens t, String text) {
    final domain = ref.watch(studioDomainProvider);
    final active = widget.activeInfo();

    final spans = <InlineSpan>[];
    if (domain == null) {
      spans.add(TextSpan(text: text));
    } else {
      var pos = 0;
      for (final h in _zitatHits(text, domain)) {
        if (h.start > pos) spans.add(TextSpan(text: text.substring(pos, h.start)));
        spans.add(TextSpan(
          text: text.substring(h.start, h.end),
          style: TextStyle(
            backgroundColor: h.color.alphaPct(30),
            decoration: TextDecoration.underline,
            decorationColor: h.color,
            decorationThickness: 2,
          ),
        ));
        pos = h.end;
      }
      if (pos < text.length) spans.add(TextSpan(text: text.substring(pos)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // srctext-bar: Aktiv-Status + ✎ Text bearbeiten
        Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: active != null
                    ? Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'aktiv: '),
                          TextSpan(
                              text: '[${active.fn}]',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(
                              text:
                                  ' — Auswahl im Text wird diesem Beleg als Zitat zugeordnet'),
                        ]),
                        style: AppTextStyles.small.copyWith(color: t.muted),
                      )
                    : Text(
                        'Kein Beleg aktiv — links einen Beleg wählen, dann Text auswählen.',
                        style: AppTextStyles.small.copyWith(color: t.warn),
                      ),
              ),
              const SizedBox(width: 8),
              AppButton(
                small: true,
                tooltip: 'Hinterlegten Text ändern/ersetzen',
                onPressed: _startEdit,
                child: const Text('✎ Text bearbeiten'),
              ),
            ],
          ),
        ),
        // srctext: Serif-Lesefläche, Auswahl → Zitat
        Expanded(
          child: Listener(
            onPointerUp: (_) => _commitSelection(text),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              child: SelectableText.rich(
                TextSpan(children: spans),
                key: ValueKey('srctext-${widget.srcId}-$_selEpoch'),
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 14.5,
                  height: 1.7,
                  color: t.ink,
                ),
                onSelectionChanged: (sel, cause) => _sel = sel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
