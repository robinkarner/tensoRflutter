/// ✦ MAGIC-DOCK — Port von `Enhance.dock` + `Enhance._cook`
/// (enhance.js:775-882): EIN kompaktes, FIXES Bedien-Modul je Stelle
/// `[ ✦ <Aktion> · Preis ] [⧉] [⭱] [ⓘ]`.
///
/// Ein-Klick-Kochen OHNE Verbreitern: die Breite wird eingefroren, das
/// Label bleibt stehen, nur der Preis-Slot zählt die Tokens live; am Ende
/// wird der ✓-Haken ins Element gespielt (Magic-✓ #2e7d32, [MagicButton]-
/// Phase `done`). Klick während des Kochens = Abbruch. Scheitert der Import
/// am Format, übergibt das Ergebnis NAHTLOS ans ⭱ Einfüge-Fenster.
///
/// Vibration: `navigator.vibrate(12)` → [HapticFeedback.lightImpact],
/// Finale `[10,40,10]` → [HapticFeedback.mediumImpact] (kein exaktes
/// Pattern-API — akzeptierte Abweichung, Dossier 08 §9.6).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/buttons.dart';
import '../client/claude_cfg.dart';
import '../client/claude_client.dart';
import '../flows/ai_flow.dart';
import '../flows/registry.dart';
import '../paste_modal/info_modal.dart';
import '../paste_modal/paste_modal.dart';
import '../panel/claude_cfg_form.dart';

/// Der EINE laufende ✦-Lauf (`Enhance._ctl`-Pendant) — Panel-Schließen und
/// Abbruch-Klicks greifen hierüber.
abstract final class AiRunHandle {
  static AiCancelToken? current;

  static void abort() {
    current?.cancel();
    current = null;
  }
}

class AiMagicDock extends ConsumerStatefulWidget {
  const AiMagicDock({
    super.key,
    required this.ctx,
    required this.flowId,
    this.compact = false,
    this.onChanged,
  });

  final AiFlowCtx ctx;
  final String flowId;

  /// `.magic-dock.compact` (Hub-Zeilen, Karten).
  final bool compact;

  /// `render`-Callback des Originals — nach Import/Config-Änderung.
  final VoidCallback? onChanged;

  @override
  ConsumerState<AiMagicDock> createState() => _AiMagicDockState();
}

class _AiMagicDockState extends ConsumerState<AiMagicDock> {
  final GlobalKey _mainKey = GlobalKey();
  MagicPhase _phase = MagicPhase.idle;
  double? _frozenWidth;
  String? _livePrice;
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  ProviderContainer get _container =>
      ProviderScope.containerOf(context, listen: false);

  AiFlow _flow() =>
      aiFlowById(buildAiFlows(_container, widget.ctx), widget.flowId);

  void _refresh() {
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  // ---- ⧉ Prompt kopieren (Feedback ✔ für 1200 ms, enhance.js:799-803) ----

  Future<void> _copy() async {
    await Clipboard.setData(
        ClipboardData(text: aiPromptFor(_container, _flow())));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  // ---- ✦ Ein-Klick-Kochen (`_cook`, enhance.js:820-882) -------------------

  Future<void> _cook() async {
    final flow = _flow();
    // (1) Erneuter Klick während busy = Abbruch.
    if (_phase == MagicPhase.busy) {
      AiRunHandle.abort();
      return;
    }
    final cfg = _container.read(claudeCfgStoreProvider.notifier).current;
    // (2) per-Flow-Modell (⚙) übersteuert den Lauf.
    final flowModel =
        _container.read(enhCfgStoreProvider.notifier).cfgFor(flow.id).model;
    final cancel = AiCancelToken();
    AiRunHandle.current = cancel;
    // (3) leichte Vibration beim Start (vibrate(12)).
    unawaited(HapticFeedback.lightImpact());
    // (4) Breite einfrieren, busy, Preis-Slot live „0 Tok“.
    final box = _mainKey.currentContext?.findRenderObject() as RenderBox?;
    setState(() {
      _frozenWidth = box?.size.width.ceilToDouble();
      _phase = MagicPhase.busy;
      _livePrice = '0 Tok';
    });

    var text = '';
    try {
      final res = await _container.read(claudeClientProvider).run(
            cfg,
            aiPromptFor(_container, flow),
            onText: (t) => text += t,
            onUsage: (u) {
              if (mounted) setState(() => _livePrice = '${fmtTok(u.output)} Tok');
            },
            cancel: cancel,
            modelId: flowModel,
          );
      if (!mounted) {
        // Dock inzwischen weg (Popover zu): der Import läuft trotzdem —
        // im Original hängen nur die UI-Updates am DOM-Anker
        // (`el.isConnected`), nicht der Import selbst.
        if (!res.demo) {
          try {
            flow.run?.call(claudeClean(text));
          } catch (_) {/* ohne UI kein pasteModal-Fallback */}
        }
        return;
      }
      if (res.demo) {
        // (6a) Demo → Finale + ehrliches Demo-Modal, KEIN Import.
        _finalize(() {
          _refresh();
          _demoModal(flow, res);
        });
        return;
      }
      final clean = claudeClean(text);
      try {
        flow.run?.call(clean);
        setState(() => _livePrice = fmtEur(res.cost));
        _finalize(() {
          final ctx = context;
          _refresh();
          flow.done?.call(ctx);
        });
      } catch (impErr) {
        // (6c) Antwort da, Format passt nicht → nahtlos ⭱ Einfüge-Fenster.
        setState(() {
          _phase = MagicPhase.idle;
          _frozenWidth = null;
          _livePrice = null;
        });
        widget.onChanged?.call();
        if (!mounted) return;
        showAiPasteModal(
          context,
          ctx: widget.ctx,
          flowId: widget.flowId,
          prefill: clean,
          autocheck: true,
          onDone: widget.onChanged,
          note:
              '✗ Automatischer Import scheiterte: ${aiErrText(impErr)} — Antwort unten prüfen/korrigieren.',
        );
      }
    } on AiAbortException {
      if (mounted) {
        setState(() {
          _phase = MagicPhase.idle;
          _frozenWidth = null;
          _livePrice = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = MagicPhase.idle;
        _frozenWidth = null;
        _livePrice = null;
      });
      _errorModal(aiErrText(e));
    } finally {
      if (identical(AiRunHandle.current, cancel)) AiRunHandle.current = null;
    }
  }

  /// Finalisierung: ✓-Haken 1250 ms, Vibration [10,40,10] (enhance.js:835-840).
  void _finalize(VoidCallback after) {
    setState(() => _phase = MagicPhase.done);
    unawaited(HapticFeedback.mediumImpact());
    Timer(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      setState(() {
        _phase = MagicPhase.idle;
        _frozenWidth = null;
        _livePrice = null;
      });
      after();
    });
  }

  /// Demo-Abschluss-Modal (enhance.js:851-859) — Texte wörtlich.
  void _demoModal(AiFlow flow, ClaudeRunResult res) {
    final t = BookClothTokens.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BookClothTokens.radiusLg)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${flow.aktion ?? flow.title} — Demo abgeschlossen',
                  style: AppTextStyles.h3.copyWith(fontSize: 15.5, color: t.ink)),
              const SizedBox(height: 10),
              Text(
                'So liefe es mit echtem Zugang: Claude streamt die Antwort, der Format-Checker prüft sie, der Import übernimmt sie an genau diese Stelle — mit echter Kostenabrechnung (hier simuliert: ~${fmtEur(res.cost)}).',
                style: AppTextStyles.small.copyWith(color: t.ink2),
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Es wurden '),
                  TextSpan(
                      text: 'keine Daten übernommen',
                      style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
                  const TextSpan(text: ' — der Demo-Modus erfindet nichts.'),
                ]),
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  AppButton(
                    small: true,
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      showClaudeConfigModal(context, onChange: _refresh);
                    },
                    child: const Text('🔑 Echten Zugang einrichten'),
                  ),
                  AppButton(
                    small: true,
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: aiPromptFor(_container, flow)));
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                      if (!mounted) return;
                      showAiPasteModal(
                        context,
                        ctx: widget.ctx,
                        flowId: widget.flowId,
                        onDone: widget.onChanged,
                        note:
                            '⧉ Prompt ist kopiert — extern ausführen, Antwort hier einfügen.',
                      );
                    },
                    child: const Text('⧉ Stattdessen extern (gratis)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fehler-Modal (enhance.js:877) — Texte wörtlich.
  void _errorModal(String message) {
    final t = BookClothTokens.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BookClothTokens.radiusLg)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GPT Magic — Fehler',
                  style: AppTextStyles.h3.copyWith(fontSize: 15.5, color: t.ink)),
              const SizedBox(height: 8),
              Text(message, style: AppTextStyles.small.copyWith(color: t.ink2)),
              const SizedBox(height: 6),
              Text(
                'Zugang prüfen (🔑) oder den Weg über ⧉ Kopieren + externes GPT nehmen — der ist immer frei.',
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  small: true,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Render --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    watchAiSources(ref);
    final flow = _flow();
    final cfg = ref.watch(claudeCfgStoreProvider).value ?? ClaudeCfg.defaults;
    final connected = cfg.hasAccess;
    final demo = !connected && cfg.isDemo;
    final ready = connected || demo;

    // Preis: Schätzung mit per-Flow-Modell (enhance.js:783-784).
    String price;
    if (_livePrice != null) {
      price = _livePrice!;
    } else if (ready) {
      String? est;
      try {
        final flowModel =
            ref.read(enhCfgStoreProvider.notifier).cfgFor(flow.id).model;
        est = fmtEur(claudeEstimate(aiPromptFor(_container, flow), flowModel).cost);
      } catch (_) {
        est = null;
      }
      price = est ?? '…';
    } else {
      price = 'einrichten →';
    }

    final mainTitle = connected
        ? 'EIN Klick: Claude führt „${flow.title}“ direkt aus — streamt, prüft, übernimmt. Geschätzte Kosten inklusive.'
        : demo
            ? 'Demo: „${flow.title}“ wird simuliert (ehrlich gekennzeichnet, es wird nichts Erfundenes übernommen)'
            : 'Kein Claude-Zugang eingerichtet — klicken zum Einrichten (global, einmalig)';

    Widget main = Tooltip(
      message: mainTitle,
      child: KeyedSubtree(
        key: _mainKey,
        child: MagicButton(
          label: flow.aktion ?? flow.title,
          variant: MagicVariant.main,
          compact: widget.compact,
          phase: _phase,
          price: price,
          priceLive: _phase == MagicPhase.busy,
          unset: !ready,
          onPressed: () {
            if (!ready) {
              showClaudeConfigModal(context, onChange: _refresh);
              return;
            }
            _cook();
          },
        ),
      ),
    );
    if (_frozenWidth != null) {
      main = SizedBox(width: _frozenWidth, child: main);
    }

    // `.magic-acts` — Schale dockt nahtlos RECHTS am orangenen Knopf an
    // (margin-left −14/−13; die linken Pixel liegen UNTER dem Knopf).
    final overlap = widget.compact ? 13.0 : 14.0;
    final shell = Transform.translate(
      offset: Offset(-overlap, 1),
      child: Container(
        padding: EdgeInsets.fromLTRB(widget.compact ? 16 : 17, 2, widget.compact ? 3 : 4, 2),
        decoration: BoxDecoration(
          color: t.surface2,
          border: Border.all(color: t.border),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(9),
            bottomRight: Radius.circular(9),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MaButton(
              index: 0,
              compact: widget.compact,
              tooltip: '⧉ Prompt kopieren — fürs externe GPT (immer frei)',
              label: _copied ? '✔' : '⧉',
              onTap: _copy,
            ),
            const SizedBox(width: 2),
            _MaButton(
              index: 1,
              compact: widget.compact,
              tooltip:
                  '⭱ Einfügen — was hier gerade gespeichert ist + externe GPT-Antwort prüfen und übernehmen',
              label: '⭱',
              onTap: () => showAiPasteModal(
                context,
                ctx: widget.ctx,
                flowId: widget.flowId,
                onDone: widget.onChanged,
              ),
            ),
            const SizedBox(width: 2),
            _MaButton(
              index: 2,
              compact: widget.compact,
              tooltip:
                  'ⓘ Überblick — wie alles zusammenhängt; von dort zu allen anderen Stellen',
              label: 'ⓘ',
              onTap: () => showAiInfoModal(context,
                  ctx: widget.ctx, currentId: widget.flowId),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label: 'GPT Magic — ${flow.aktion ?? flow.title}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [main, shell],
      ),
    );
  }
}

/// `.ma` — Mini-Menü-Knopf (25×25 / 23×23 kompakt) mit maIn-Stagger
/// (opacity 0→1, translateX −5→0, Delay `i*50ms + 40ms`, app.css:1836-1843).
class _MaButton extends StatefulWidget {
  const _MaButton({
    required this.index,
    required this.compact,
    required this.tooltip,
    required this.label,
    required this.onTap,
  });

  final int index;
  final bool compact;
  final String tooltip;
  final String label;
  final VoidCallback onTap;

  @override
  State<_MaButton> createState() => _MaButtonState();
}

class _MaButtonState extends State<_MaButton> {
  bool _hover = false;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 50 + 40), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final size = widget.compact ? 23.0 : 25.0;
    final visible = _shown || reduceMotion;

    return Tooltip(
      message: widget.tooltip,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        opacity: visible ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          offset: visible ? Offset.zero : Offset(-5 / size, 0),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _hover ? t.accentSoft : t.surface,
                  border:
                      Border.all(color: _hover ? t.accent : t.borderStrong),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: widget.compact ? 11.5 : 12.5,
                    height: 1,
                    color: _hover ? t.accentInk : t.ink2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
