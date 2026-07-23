/// Absatz-Doppelklick-Bearbeitung — Port von `paraEditStart`
/// (views_studio.js:790-833) samt `.para-card.editing`/`.edit-hint`
/// (app.css:1594-1622):
///
/// Der Absatztext wird in ROHFORM (mit `[^n]`-Markern) an Ort und Stelle
/// editierbar — hier als deckungsgleiches Overlay über der Karte (die Karte
/// selbst gehört S-2; der Slot [StudioSlots.paraEditStart] ist ein Callback).
/// **Esc UND Klick außerhalb/Fokusverlust = ÜBERNEHMEN** (kein Verwerfen!).
///
/// Beim Übernehmen: Whitespace normalisieren; Override in `paraEdits`
/// (Text == Original ⇒ Eintrag löschen — §0-Sync macht [StudioKv.put]);
/// danach das LaTeX des Abschnitts synchron halten
/// (`Editor.saveEdit(sectionId, Editor.reconstruct(sectionId))`) und den
/// Mentions-Cache des Absatzes invalidieren.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../layout/studio_state.dart';

/// Slot-Einstieg (`StudioSlots.paraEditStart`).
void startParaEdit(BuildContext context, String sectionId, Paragraph p) {
  if (!p.isText) return;
  final container = ProviderScope.containerOf(context, listen: false);

  // Position/Breite der Karte — das Overlay liegt deckungsgleich darüber.
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context, rootOverlay: true);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (box == null || overlayBox == null) return;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ParaEditOverlay(
      container: container,
      sectionId: sectionId,
      paragraph: p,
      left: topLeft.dx,
      top: topLeft.dy,
      width: box.size.width,
      onClose: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

/// Übernahme-Logik (getrennt vom Widget — direkt testbar):
/// normalisierter Text → `paraEdits`-Override (== Original ⇒ löschen) +
/// LaTeX-Sync + Mentions-Invalidierung. Liefert den normalisierten Text.
String commitParaEdit(
  ProviderContainer container, {
  required String sectionId,
  required String paraId,
  required String rawInput,
}) {
  // Whitespace-Normalisierung wie :805 (nbsp → Space, Zeilenumbrüche → Space).
  final t = rawInput
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'\n+'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  if (t.isEmpty) return t;

  // Original-Text (Ground Truth) aus der UN-überschriebenen Runtime.
  final runtime = container.read(activeRuntimeProvider);
  String? orig;
  void walk(List<Unit> units) {
    for (final u in units) {
      for (final p in u.paragraphs) {
        if (p.id == paraId) orig = p.text;
      }
      walk(u.children);
    }
  }

  for (final ch in runtime?.thesis.chapters ?? const <Chapter>[]) {
    walk(ch.sections);
  }

  final kv = container.read(studioKvProvider.notifier);
  final current = kv.readMap(KvKeys.paraEdits);
  final effective = current[paraId] is String
      ? current[paraId] as String
      : (orig ?? '');
  if (t == effective) return t; // unverändert — nichts zu tun (:813)

  final next = {...current};
  if (orig != null && t == orig) {
    next.remove(paraId);
  } else {
    next[paraId] = t;
  }
  kv.put(KvKeys.paraEdits, next); // §0: Overrides zieht StudioKv selbst nach

  // LaTeX synchron halten — mit der FRISCHEN Domäne (nach dem Override).
  final domain = container.read(studioDomainProvider);
  if (domain != null) {
    domain.editor.saveEdit(sectionId, domain.editor.reconstruct(sectionId));
    domain.mentions.invalidate();
  }
  return t;
}

class _ParaEditOverlay extends StatefulWidget {
  const _ParaEditOverlay({
    required this.container,
    required this.sectionId,
    required this.paragraph,
    required this.left,
    required this.top,
    required this.width,
    required this.onClose,
  });

  final ProviderContainer container;
  final String sectionId;
  final Paragraph paragraph;
  final double left;
  final double top;
  final double width;
  final VoidCallback onClose;

  @override
  State<_ParaEditOverlay> createState() => _ParaEditOverlayState();
}

class _ParaEditOverlayState extends State<_ParaEditOverlay> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.paragraph.text);
  final FocusNode _focus = FocusNode();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Esc/Blur/Klick außerhalb = ÜBERNEHMEN — läuft nur EINMAL (:801-826).
  void _finish() {
    if (_done) return;
    _done = true;
    commitParaEdit(
      widget.container,
      sectionId: widget.sectionId,
      paraId: widget.paragraph.id,
      rawInput: _ctl.text,
    );
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final screenH = MediaQuery.sizeOf(context).height;
    // Obergrenze nie unter die Untergrenze fallen lassen (clamp mit
    // min > max würde sonst werfen, wenn der Viewport < 160px hoch ist).
    final maxH = (screenH - widget.top - 20)
        .clamp(160.0, screenH < 160.0 ? 160.0 : screenH);

    return Stack(
      children: [
        // Klick außerhalb übernimmt (Blur-Pendant).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _finish,
          ),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          width: widget.width,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(maxHeight: maxH),
              decoration: BoxDecoration(
                color: t.accent.mix(t.surface, 6),
                border: Border.all(color: t.accentLine),
                borderRadius: BorderRadius.circular(BookClothTokens.radius),
                boxShadow: [
                  BoxShadow(
                    color: t.accent.alphaPct(45),
                    spreadRadius: 2,
                    blurRadius: 0,
                  ),
                  ...t.shadow2,
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    child: SingleChildScrollView(
                      child: Focus(
                        onKeyEvent: (node, e) {
                          if (e is KeyDownEvent &&
                              e.logicalKey == LogicalKeyboardKey.escape) {
                            _finish(); // Esc = fertig (ÜBERNEHMEN)
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: _ctl,
                          focusNode: _focus,
                          maxLines: null,
                          cursorColor: t.accent,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 16,
                            height: 1.75,
                            color: t.ink,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            isCollapsed: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // `.edit-hint` oben rechts.
                  Positioned(
                    top: 8,
                    right: 10,
                    child: Tooltip(
                      message:
                          'Direkt im Text schreiben — Esc oder Klick außerhalb übernimmt',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: t.accentSoft,
                          border: Border.all(color: t.accentLine),
                          borderRadius: BorderRadius.circular(
                              BookClothTokens.radiusPill),
                        ),
                        child: Text(
                          '✎ Bearbeitung · Esc fertig',
                          style: TextStyle(
                            fontFamily: AppFonts.ui,
                            fontFamilyFallback: AppFonts.fallback,
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                            height: 1,
                            color: t.accentInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
