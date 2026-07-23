/// ⓘ Konzept-Fenster (ZENTRAL) — Port von `Enhance.infoModal`
/// (enhance.js:960-1016): erklärt JEDEN Button-Typ einzeln — Textbasis →
/// Modell → erzeugt → Integration — plus Ersetzen-Semantik („was passiert
/// beim erneuten Lauf?“), der Garantie „Originaltext bleibt unangetastet“
/// und dem Vergleich aller sechs Typen auf einen Blick.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/chips.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/modal.dart';
import '../client/claude_cfg.dart';
import '../flows/ai_flow.dart';
import '../flows/registry.dart';
import '../panel/claude_cfg_form.dart';
import '../panel/enhance_panel.dart';
import 'paste_modal.dart';

void showAiInfoModal(BuildContext context, {required AiFlowCtx ctx, String? currentId}) {
  showAppModal<void>(
    context,
    title: const Text('GPT Magic — das Konzept'),
    body: _InfoBody(ctx: ctx, currentId: currentId),
  );
}

class _InfoBody extends ConsumerStatefulWidget {
  const _InfoBody({required this.ctx, this.currentId});

  final AiFlowCtx ctx;
  final String? currentId;

  @override
  ConsumerState<_InfoBody> createState() => _InfoBodyState();
}

class _InfoBodyState extends ConsumerState<_InfoBody> {
  late String _curId = widget.currentId ?? 'all';
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    watchAiSources(ref);
    final container = ProviderScope.containerOf(context, listen: false);
    final flows = [
      for (final f in buildAiFlows(container, widget.ctx))
        if (!f.toggle) f,
    ];
    final cur = aiFlowById(flows, _curId);
    final acc = aiAccessInfo(
        ref.watch(claudeCfgStoreProvider).value ?? ClaudeCfg.defaults);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `.gt-note` — Garantie-Banner (accent-soft, 3px-Kante links).
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: t.accentSoft,
            border: Border(
              left: BorderSide(color: t.accent, width: 3),
              top: BorderSide(color: t.accentLine),
              right: BorderSide(color: t.accentLine),
              bottom: BorderSide(color: t.accentLine),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Σ',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.3,
                    color: t.accentInk,
                  )),
              const SizedBox(width: 11),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'Der Originaltext wird nie angegriffen.',
                        style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
                    const TextSpan(
                        text: ' Das LaTeX der Arbeit ist Ground Truth — jede Generierung ist eine '),
                    TextSpan(
                        text: 'eigene Ebene darüber',
                        style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
                    const TextSpan(text: ': einzeln ersetzbar, entfernbar, exportierbar.'),
                  ]),
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 12.5,
                    height: 1.55,
                    color: t.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
        // `.im-tabs` — Typ-Tabs (aktiver Tab im Magic-Block-Stil).
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final f in flows)
              _ImTab(
                icon: f.icon,
                label: f.aktion ?? f.title,
                on: f.id == cur.id,
                onTap: () => setState(() {
                  _curId = f.id;
                  _copied = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // `.im-body`
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border.all(color: t.borderStrong),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // `.im-pipe`: Basis → GPT / Claude → erzeugt → Ziel.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Tooltip(
                    message:
                        'Worauf diese Generierung basiert — reiner Lesezugriff, nichts wird verändert',
                    child: _ip(t, cur.basis ?? '', gt: true),
                  ),
                  _ipArrow(t),
                  _ip(t, 'GPT / Claude', ki: true),
                  _ipArrow(t),
                  _ip(t, cur.paket?.out ?? cur.erzeugt),
                  _ipArrow(t),
                  _ip(t, cur.paket?.ziel ?? '', ok: true),
                ],
              ),
              const SizedBox(height: 10),
              Text(cur.how,
                  style: AppTextStyles.small.copyWith(height: 1.6, color: t.ink2)),
              const SizedBox(height: 10),
              // `.im-int`: Ersetzen-Semantik.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: t.surface2,
                  border: Border.all(color: t.borderStrong),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const AppChip(
                        label: 'beim erneuten Lauf',
                        variant: AppChipVariant.warn,
                        mini: true),
                    Text(cur.wieder ?? '',
                        style: AppTextStyles.small
                            .copyWith(fontSize: 12.5, height: 1.55, color: t.ink2)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // `.im-live`: Stand + Aktionen.
              Row(
                children: [
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Aktueller Stand: '),
                      TextSpan(
                          text: cur.stat?.call() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    style: AppTextStyles.small.copyWith(color: t.ink),
                  ),
                  const Spacer(),
                  AppButton(
                    small: true,
                    onPressed: () async {
                      final c = ProviderScope.containerOf(context, listen: false);
                      await Clipboard.setData(
                          ClipboardData(text: aiPromptFor(c, cur)));
                      if (mounted) setState(() => _copied = true);
                      Future.delayed(const Duration(milliseconds: 1200), () {
                        if (mounted) setState(() => _copied = false);
                      });
                    },
                    child: Text(_copied ? '✔ kopiert' : '⧉ Prompt kopieren'),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    small: true,
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      final nav = Navigator.of(context, rootNavigator: true);
                      closeAppModal();
                      showAiPasteModal(nav.context,
                          ctx: widget.ctx, flowId: cur.id);
                    },
                    child: const Text('⭱ Einfüge-Fenster'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Eyebrow('Die sechs Typen im Vergleich'),
        const SizedBox(height: 6),
        // `.tbl.im-cmp` — Vergleichstabelle, aktive Zeile accent-soft.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _cmpTable(t, flows, cur),
        ),
        // `.pm-foot`
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.only(top: 10),
          decoration:
              BoxDecoration(border: Border(top: BorderSide(color: t.border))),
          child: Row(
            children: [
              AppButton(
                small: true,
                onPressed: () {
                  final nav = Navigator.of(context, rootNavigator: true);
                  closeAppModal();
                  showClaudeConfigModal(nav.context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔑 Zugang'),
                    const SizedBox(width: 4),
                    AppChip(label: acc.label, mini: true),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                small: true,
                tooltip:
                    'Die volle Werkbank (rechts): alle Aktionen, Referenzen, Konfiguration je Stelle',
                onPressed: () {
                  final ctx = widget.ctx;
                  final id = cur.id;
                  final nav = Navigator.of(context, rootNavigator: true);
                  closeAppModal();
                  openEnhancePanel(nav.context, ctx: ctx, activeId: id);
                },
                child: const Text('⧈ Werkbank öffnen'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ipArrow(BookClothTokens t) =>
      Text('→', style: TextStyle(fontSize: 12, color: t.muted));

  /// `.im-pipe .ip[.gt|.ki|.ok]` — Pill 600 11.5.
  Widget _ip(BookClothTokens t, String label,
      {bool gt = false, bool ki = false, bool ok = false}) {
    final (Color fg, Color bg, Color border) = gt
        ? (t.accentInk, t.accentSoft, t.accentLine)
        : ki
            ? (t.ki, t.kiSoft, t.ki.mix(t.border, 45))
            : ok
                ? (t.good, t.goodSoft, t.good.mix(t.border, 45))
                : (t.ink2, t.surface2, t.borderStrong);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontFamilyFallback: AppFonts.fallback,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
          height: 1.3,
          color: fg,
        ),
      ),
    );
  }

  Widget _cmpTable(BookClothTokens t, List<AiFlow> flows, AiFlow cur) {
    TextStyle th = TextStyle(
      fontFamily: AppFonts.display,
      fontFamilyFallback: AppFonts.fallback,
      fontWeight: FontWeight.w600,
      fontSize: 11,
      height: 1.3,
      letterSpacing: .08 * 11,
      color: t.muted,
    );
    TextStyle td = AppTextStyles.small.copyWith(fontSize: 12.5, color: t.ink2);

    TableRow row(AiFlow f) => TableRow(
          decoration:
              BoxDecoration(color: f.id == cur.id ? t.accentSoft : null),
          children: [
            _cell(Text('${f.icon} ${f.aktion}',
                style: td.copyWith(fontWeight: FontWeight.w700, color: t.ink))),
            _cell(Text(f.basis ?? '', style: td)),
            _cell(Text(f.paket?.out ?? f.erzeugt, style: td)),
            _cell(Text(f.paket?.ziel ?? '', style: td)),
          ],
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 560),
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder(
          horizontalInside: BorderSide(color: t.border),
          bottom: BorderSide(color: t.border),
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.borderStrong)),
            ),
            children: [
              _cell(Text('TYP', style: th)),
              _cell(Text('TEXTBASIS', style: th)),
              _cell(Text('ERZEUGT', style: th)),
              _cell(Text('LANDET IN', style: th)),
            ],
          ),
          for (final f in flows) row(f),
        ],
      ),
    );
  }

  Widget _cell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: child,
      );
}

/// `.im-tab` — Typ-Tab mit Hover-Leben; `.on` im Magic-Block-Stil.
class _ImTab extends StatefulWidget {
  const _ImTab({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_ImTab> createState() => _ImTabState();
}

class _ImTabState extends State<_ImTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final on = widget.on;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: const Cubic(.2, .9, .3, 1.2),
          transform: Matrix4.translationValues(0, _hover && !on ? -1.5 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? t.magicTop : t.surface2,
            border: Border.all(
              color: on
                  ? t.magicEdge
                  : _hover
                      ? t.accent
                      : t.border,
              width: on ? 1 : 1,
            ),
            borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
            boxShadow: on
                ? [BoxShadow(offset: const Offset(0, 2), color: t.magicEdge)]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 13, height: 1)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  height: 1,
                  color: on
                      ? Colors.white
                      : _hover
                          ? t.ink
                          : t.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
