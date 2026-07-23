/// ✦ GPT-Magic-Bar — Port des `U.gptModal`-Magic-Teils (util.js:812-908):
/// der eine, wiedererkennbare Magic-Knopf „Mit Claude ausführen“ + die
/// Werkzeug-Chips ⧉ Prompt · ✎ Bearbeiten · ⚙ Zugang, darunter die
/// Statuszeile (`.ai-run`).
///
/// Andockstelle: [QuellenGptHooks.magicBar] (S-4-GPT-Dialoge: ✦ Durchlauf,
/// 🤖 Ergänzung) — die Bar streamt die Antwort über [onAnswer] ins
/// Antwortfeld des Dialogs; übernommen wird dort über „⭱ Übernehmen“
/// (der Auto-Import des Originals läuft im Dialog-Import-Pfad — bewusste
/// kleine Abweichung: der Format-Checker des Dialogs meldet sich vorher).
///
/// ⚙ öffnet das Zugangsformular INLINE (`.ai-cfg`) — ein eigenes Modal
/// würde wegen der Ein-Modal-Semantik den GPT-Dialog schließen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/color_mix.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/format.dart';
import '../client/claude_cfg.dart';
import '../client/claude_client.dart';
import '../dock/magic_dock.dart';
import '../panel/claude_cfg_form.dart';

class AiMagicBar extends ConsumerStatefulWidget {
  const AiMagicBar({super.key, required this.prompt, required this.onAnswer});

  /// Der fertige Prompt der Stelle (baut der Dialog).
  final String prompt;

  /// Streaming-Ziel: bekommt die (akkumulierte) Antwort — am Ende die
  /// bereinigte Fassung (`ClaudeAI.clean`).
  final ValueChanged<String> onAnswer;

  @override
  ConsumerState<AiMagicBar> createState() => _AiMagicBarState();
}

enum _Tone { none, working, done, err, demo }

class _AiMagicBarState extends ConsumerState<AiMagicBar> {
  final TextEditingController _promptCtl = TextEditingController();
  bool _editOpen = false;
  bool _cfgOpen = false;
  bool _copied = false;
  bool _running = false;
  String _runText = '';
  _Tone _tone = _Tone.none;
  String? _override;

  String get _effPrompt => _override ?? widget.prompt;

  @override
  void dispose() {
    _promptCtl.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _effPrompt));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _magic() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final cfg = container.read(claudeCfgStoreProvider.notifier).current;
    if (!cfg.ready) {
      setState(() => _cfgOpen = true);
      return;
    }
    if (_running) {
      AiRunHandle.abort();
      return;
    }
    final cancel = AiCancelToken();
    AiRunHandle.current = cancel;
    setState(() {
      _running = true;
      _tone = _Tone.working;
      _runText = 'Claude verbindet …';
    });
    var text = '';
    try {
      final res = await container.read(claudeClientProvider).run(
            cfg,
            _effPrompt,
            onText: (t) {
              text += t;
              widget.onAnswer(text);
            },
            onThink: (_) {
              if (mounted && _runText == 'Claude verbindet …') {
                setState(() => _runText = 'Claude denkt …');
              }
            },
            onUsage: (u) {
              if (mounted) {
                setState(() =>
                    _runText = 'Claude schreibt … ${fmtTok(u.output)} Tokens');
              }
            },
            cancel: cancel,
          );
      if (!mounted) return;
      if (res.demo) {
        setState(() {
          _tone = _Tone.demo;
          _runText =
              'Demo abgeschlossen (${fmtTok(res.usage.input)} Tokens · ~${fmtUsd(res.cost)}). Echten Zugang einrichten für übernehmbare Ergebnisse.';
        });
      } else {
        widget.onAnswer(claudeClean(text));
        setState(() {
          _tone = _Tone.done;
          _runText =
              '✓ Fertig · ${fmtTok(res.usage.input)}→${fmtTok(res.usage.output)} Tokens · ${fmtUsd(res.cost)}';
        });
      }
    } on AiAbortException {
      if (mounted) {
        setState(() {
          _tone = _Tone.none;
          _runText = 'Abgebrochen.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tone = _Tone.err;
          _runText = '✗ ${e is FormatException ? e.message : e}';
        });
      }
    } finally {
      if (identical(AiRunHandle.current, cancel)) AiRunHandle.current = null;
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final cfg = ref.watch(claudeCfgStoreProvider).value ?? ClaudeCfg.defaults;
    final ready = cfg.ready;
    final demo = cfg.isDemo;

    String sub;
    if (!ready) {
      sub = 'Zugang einrichten →';
    } else {
      try {
        final est = claudeEstimate(_effPrompt);
        sub = '≈ ${fmtUsd(est.cost)} · ${est.model.label}${demo ? ' · Demo' : ''}';
      } catch (_) {
        sub = cfg.modelDef().label + (demo ? ' · Demo' : '');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `.ai-bar`
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tooltip(
              message:
                  'Prompt direkt an Claude senden — Antwort wird gestreamt und übernommen',
              child: _DialogMagicButton(
                label: _running ? 'Abbrechen' : 'Mit Claude ausführen',
                sub: sub,
                unset: !ready,
                busy: _running,
                onTap: _magic,
              ),
            ),
            _chip(t, _copied ? '✔ kopiert' : '⧉ Prompt',
                tooltip:
                    'Prompt in die Zwischenablage — für ein eigenes GPT/Claude',
                onTap: _copy),
            _chip(t, '✎ Bearbeiten',
                on: _editOpen,
                tooltip: 'Prompt ansehen und vor dem Senden anpassen',
                onTap: () {
              setState(() {
                _editOpen = !_editOpen;
                if (_editOpen) _promptCtl.text = _effPrompt;
              });
            }),
            _chip(t, '⚙',
                on: _cfgOpen,
                tooltip: 'Claude-Zugang: Key/Endpunkt, Modell, Preis',
                onTap: () => setState(() => _cfgOpen = !_cfgOpen)),
          ],
        ),
        if (_cfgOpen)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: t.surface2,
              border: Border.all(color: t.borderStrong),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClaudeCfgForm(onChange: () {
              if (mounted) setState(() {});
            }),
          ),
        if (_editOpen)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _promptCtl,
              minLines: 6,
              maxLines: 12,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 11.5,
                height: 1.5,
                color: t.ink,
              ),
              onChanged: (v) => setState(
                  () => _override = v == widget.prompt ? null : v),
            ),
          ),
        if (_runText.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: switch (_tone) {
                _Tone.done => t.goodSoft,
                _Tone.err => t.badSoft,
                _Tone.demo => t.kiSoft,
                _ => t.surface2,
              },
              border: Border.all(
                color: switch (_tone) {
                  _Tone.working => t.ki.mix(t.border, 42),
                  _Tone.done => t.good.mix(t.border, 40),
                  _Tone.err => t.bad.mix(t.border, 34),
                  _Tone.demo => t.ki.mix(t.border, 40),
                  _Tone.none => t.border,
                },
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _runText,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.4,
                color: switch (_tone) {
                  _Tone.working || _Tone.demo => t.ki,
                  _Tone.done => t.good,
                  _Tone.err => t.bad,
                  _Tone.none => t.ink2,
                },
              ),
            ),
          ),
      ],
    );
  }

  /// `.ai-chip[.on]`.
  Widget _chip(BookClothTokens t, String label,
      {required String tooltip, required VoidCallback onTap, bool on = false}) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? t.accentSoft : t.surface,
              border: Border.all(color: on ? t.accent : t.borderStrong),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1,
                color: on ? t.accentInk : t.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.ai-magic` — der Dialog-Block-Knopf (min-height 54, Baloo-Hauptzeile,
/// Mono-Subzeile; busy = grauer Verlauf).
class _DialogMagicButton extends StatefulWidget {
  const _DialogMagicButton({
    required this.label,
    required this.sub,
    required this.unset,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool unset;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_DialogMagicButton> createState() => _DialogMagicButtonState();
}

class _DialogMagicButtonState extends State<_DialogMagicButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final down = _pressed && !widget.busy;

    Widget block = Container(
      constraints: const BoxConstraints(minHeight: 54, minWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      transform: Matrix4.translationValues(0, down ? 3 : 0, 0),
      decoration: BoxDecoration(
        color: widget.busy ? null : t.magicTop,
        gradient: widget.busy
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  BookClothTokens.magicBusyA,
                  BookClothTokens.magicBusyB,
                ],
              )
            : null,
        border: Border.all(color: t.magicEdge, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: down || widget.busy
            ? const []
            : [BoxShadow(offset: const Offset(0, 3), color: t.magicEdge)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontFamily: AppFonts.magic,
              fontFamilyFallback: AppFonts.magicFallbackChain,
              fontWeight: FontWeight.w500,
              fontSize: 15.5,
              height: 1.15,
              color: BookClothTokens.magicText,
            ),
          ),
          const SizedBox(height: 1),
          Opacity(
            opacity: widget.unset ? 1 : .92,
            child: Text(
              widget.sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
                height: 1.2,
                color: BookClothTokens.magicText,
                decoration: widget.unset
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.unset && !widget.busy) {
      block = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          .6, .2, .2, 0, 0, //
          .2, .6, .2, 0, 0,
          .2, .2, .6, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: block,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: block,
      ),
    );
  }
}
