/// Generate-GPT-Hub — Port von `Enhance.hub`/`Enhance.hubCtx`
/// (enhance.js:643-704): DER Ort für alle KI in EINEM Topbar-Menü — jede
/// Funktion als Zeile mit Schnellauswahl (EIN Klick kocht · ⧉ Prompt ·
/// ⭱ Einfügen · ⓘ Konzept). Hierarchie: ⚡ Voranalyse ist die Wurzel,
/// ⤳/🎛 schärfen ihre Pakete einzeln nach; darunter der Studio-Kontext.
///
/// Die Popover-Hülle (`.gpt-pop`) stellt die Topbar (core/shell) — dieses
/// Widget ist ihr Inhalt (gp-list + gp-foot).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/db/kv.dart';
import '../../studio/layout/studio_state.dart';
import '../client/claude_cfg.dart';
import '../dock/magic_dock.dart';
import '../flows/ai_flow.dart';
import '../flows/registry.dart';
import '../panel/claude_cfg_form.dart';
import '../panel/enhance_panel.dart';
import '../paste_modal/info_modal.dart';
import '../paste_modal/stand_modal.dart';

/// `Enhance.hubCtx()`: Kontext aus der Route ableiten — nur im Studio
/// werden Abschnitt + aktive Quelle mitgenommen (enhance.js:649-656).
/// Ohne Routen-Abschnitt zählt der zuletzt geöffnete (`studioLast` —
/// das Pendant zu `Studio.sectionId`, das der Studio-Render setzt).
AiFlowCtx aiHubCtx(ProviderContainer c, String location) {
  final path = location.split('?').first;
  if (!path.startsWith('/studio')) return const AiFlowCtx();
  String? sectionId;
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.length > 1 && segments[1].isNotEmpty) {
    sectionId = Uri.decodeComponent(segments[1]);
  } else {
    final last = (c.read(studioKvProvider).value ?? const {})[KvKeys.studioLast];
    if (last is String && last.isNotEmpty) sectionId = last;
  }
  final srcId = c.read(studioFileProvider).srcId;
  return AiFlowCtx(sectionId: sectionId, srcId: srcId);
}

class GptHubCard extends ConsumerWidget {
  const GptHubCard({super.key, required this.location, required this.onDismiss});

  /// Aktuelle Router-Location (Kontext-Ableitung beim Öffnen).
  final String location;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    watchAiSources(ref);
    final container = ProviderScope.containerOf(context, listen: false);
    final ctx = aiHubCtx(container, location);
    final flows = [
      for (final f in buildAiFlows(container, ctx))
        if (!f.toggle) f,
    ];
    AiFlow? byId(String id) {
      for (final f in flows) {
        if (f.id == id) return f;
      }
      return null;
    }

    final srcId = aiQuellenSrcFor(container, ctx);
    final srcShort = srcId != null ? ref.watch(srcShortProvider(srcId)) : null;
    final acc = aiAccessInfo(
        ref.watch(claudeCfgStoreProvider).value ?? ClaudeCfg.defaults);
    final screenH = MediaQuery.sizeOf(context).height;
    final listMax = (screenH * .62).clamp(0.0, 520.0);

    final ctxChip = [
      if (ctx.sectionId != null) 'Abschnitt ${ctx.sectionId}',
      ?srcShort,
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `.gp-list`
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: listMax),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _grp(t, 'Ganze Arbeit', first: true),
                  if (byId('all') != null)
                    _HubRow(ctx: ctx, flow: byId('all')!, kind: _RowKind.root),
                  if (byId('conn') != null)
                    _HubRow(ctx: ctx, flow: byId('conn')!, kind: _RowKind.child),
                  if (byId('inst') != null)
                    _HubRow(ctx: ctx, flow: byId('inst')!, kind: _RowKind.child),
                  if (byId('buch') != null)
                    _HubRow(ctx: ctx, flow: byId('buch')!, kind: _RowKind.plain),
                  _grp(t, 'Im Studio-Kontext',
                      chip: ctxChip.isNotEmpty
                          ? ctxChip
                          : 'im Studio öffnen — Abschnitt & Quelle'),
                  if (byId('marks') != null)
                    _HubRow(ctx: ctx, flow: byId('marks')!, kind: _RowKind.plain),
                  if (byId('quellen') != null)
                    _HubRow(
                        ctx: ctx, flow: byId('quellen')!, kind: _RowKind.plain),
                ],
              ),
            ),
          ),
        ),
        // `.gp-foot`
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface2,
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _GpTool(
                label: 'ⓘ Konzept',
                tooltip:
                    'Das Konzept: jeder Typ erklärt — Textbasis → erzeugt → Integration',
                onTap: () {
                  onDismiss();
                  showAiInfoModal(context,
                      ctx: ctx, currentId: flows.first.id);
                },
              ),
              _GpTool(
                label: '⧈ Werkbank',
                tooltip:
                    'Die volle Werkbank: Referenzen, Format-Checker, ⚙ je Stelle',
                onTap: () {
                  onDismiss();
                  openEnhancePanel(context, ctx: ctx);
                },
              ),
              _GpTool(
                label: '⎇ Stand',
                tooltip:
                    'Speicherstand wie ein Log: was ist gespeichert, in welchem Format, aus welcher Quelle — für beide Arbeiten',
                onTap: () {
                  onDismiss();
                  showAiStandModal(context);
                },
              ),
              const SizedBox(width: 14),
              _GpBrand(
                label: 'Claude',
                color: BookClothTokens.brandClaude,
                edge: BookClothTokens.brandClaudeEdge,
                dot: acc.dot,
                tooltip:
                    'Zugang: direkt mit Claude verbinden (eigener Key oder AI-Space) — Status: ${acc.label}',
                onTap: () {
                  onDismiss();
                  showClaudeConfigModal(context);
                },
              ),
              _GpBrand(
                label: 'OpenAI',
                color: BookClothTokens.brandOpenAi,
                edge: BookClothTokens.brandOpenAiEdge,
                dot: null,
                tooltip:
                    'Zugang: extern mit ChatGPT/OpenAI — ⧉ Prompt kopieren, Antwort ⭱ einfügen (gratis, ohne Konto in der App)',
                onTap: () {
                  onDismiss();
                  showClaudeConfigModal(context);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// `.gp-grp` — Gruppen-Kopf mit optionalem Kontext-Chip (`.gg-ctx`).
  Widget _grp(BookClothTokens t, String label, {String? chip, bool first = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, first ? 4 : 9, 4, 3),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1,
              letterSpacing: .09 * 10,
              color: t.muted,
            ),
          ),
          if (chip != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: t.accentSoft,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  chip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                    height: 1.2,
                    color: t.accentInk,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _RowKind { root, child, plain }

/// `.gp-row[.root|.child]` — eine Flow-Zeile mit kompaktem Magic-Dock.
class _HubRow extends StatefulWidget {
  const _HubRow({required this.ctx, required this.flow, required this.kind});

  final AiFlowCtx ctx;
  final AiFlow flow;
  final _RowKind kind;

  @override
  State<_HubRow> createState() => _HubRowState();
}

class _HubRowState extends State<_HubRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final f = widget.flow;
    final on = f.statOn?.call() ?? false;
    final stat = f.stat?.call() ?? '';

    final row = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: widget.kind == _RowKind.root
              ? t.surface2
              : _hover
                  ? t.surface2
                  : Colors.transparent,
          border: widget.kind == _RowKind.root
              ? Border.all(color: t.border)
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(f.icon,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontFamilyFallback: AppFonts.fallback,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.2,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    f.kurz ?? f.erzeugt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 11,
                      height: 1.3,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // `.gp-n[.on]` — Stand-Badge.
            Tooltip(
              message: 'Aktueller Stand dieser Stelle',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: t.surface2,
                  border: Border.all(
                      color: on ? t.good.withValues(alpha: .55) : t.border),
                  borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
                ),
                child: Text(
                  stat,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: on ? t.good : t.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            AiMagicDock(ctx: widget.ctx, flowId: f.id, compact: true),
          ],
        ),
      ),
    );

    if (widget.kind != _RowKind.child) return row;
    // `.gp-row.child`: eingerückt mit Ellenbogen-Linie (::before).
    return Padding(
      padding: const EdgeInsets.only(left: 26),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -15,
            top: -6,
            child: CustomPaint(
              size: const Size(12, 28),
              painter: _ElbowPainter(t.borderStrong),
            ),
          ),
          row,
        ],
      ),
    );
  }
}

/// Der Hierarchie-„Ellenbogen“ der Kind-Zeilen (border-left+bottom, r 8).
class _ElbowPainter extends CustomPainter {
  const _ElbowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    final path = Path()
      ..moveTo(1, 0)
      ..lineTo(1, size.height - 9)
      ..quadraticBezierTo(1, size.height - 1, 9, size.height - 1)
      ..lineTo(size.width, size.height - 1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ElbowPainter oldDelegate) => oldDelegate.color != color;
}

/// `.gp-tool` — Werkzeug im Block-Stil, neutral (app.css:1909-1916).
class _GpTool extends StatefulWidget {
  const _GpTool({required this.label, required this.tooltip, required this.onTap});

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_GpTool> createState() => _GpToolState();
}

class _GpToolState extends State<_GpTool> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = _pressed = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.borderStrong, width: 2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: _pressed
                  ? const []
                  : [BoxShadow(offset: const Offset(0, 2), color: t.borderStrong)],
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: AppFonts.magic,
                fontFamilyFallback: AppFonts.magicFallbackChain,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1,
                color: _hover ? t.ink : t.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.gp-brand[.claude|.openai]` — Marken-Block mit Status-Punkt.
class _GpBrand extends StatefulWidget {
  const _GpBrand({
    required this.label,
    required this.color,
    required this.edge,
    required this.dot,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color edge;

  /// null = neutraler Punkt (OpenAI), sonst Zugangs-Status (Claude).
  final AiAccessDot? dot;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_GpBrand> createState() => _GpBrandState();
}

class _GpBrandState extends State<_GpBrand> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (widget.dot) {
      AiAccessDot.on => BookClothTokens.brandDotOn,
      AiAccessDot.demo => BookClothTokens.brandDotDemo,
      _ => const Color(0x80FFFFFF),
    };
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = _pressed = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
            foregroundDecoration: _hover
                ? BoxDecoration(
                    color: Colors.white.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            decoration: BoxDecoration(
              color: widget.color,
              border: Border.all(color: widget.edge, width: 2),
              borderRadius: BorderRadius.circular(6),
              boxShadow: _pressed
                  ? const []
                  : [BoxShadow(offset: const Offset(0, 2), color: widget.edge)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.dot != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: dotColor),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontFamily: AppFonts.magic,
                    fontFamilyFallback: AppFonts.magicFallbackChain,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    height: 1,
                    color: Color(0xFFF1EBE2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
