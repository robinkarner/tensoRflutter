/// Flow-Ansicht im Werkbank-Panel — Port von `Enhance._show`
/// (enhance.js:443-544) samt ⚙-Konfiguration (`_cfgHtml`/`_wireCfg`) und
/// dem kleinen ⓘ-Info-Modal (`Enhance._info`).
///
/// ✦ „Mit Claude“: Das Original referenziert `Enhance._runMagic`, die
/// Funktion existiert dort aber NICHT (toter Verweis — der Klick lief ins
/// Leere). Der Port baut den offensichtlich gemeinten Ablauf nach dem
/// `U.gptModal`-Muster (util.js:840-891): Streamen in die Antwort-Textarea,
/// Statuszeile (`.enh-run` working/done/err/demo), bei Erfolg automatischer
/// Import — dokumentierte Abweichung.
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
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
import '../../../core/util/format.dart';
import '../../studio/layout/studio_state.dart';
import '../client/claude_cfg.dart';
import '../client/claude_client.dart';
import '../client/claude_models.dart';
import '../dock/magic_dock.dart';
import '../flows/ai_flow.dart';
import '../flows/checkers.dart';
import '../flows/registry.dart';
import '../paste_modal/paste_modal.dart';
import '../widgets/ai_bits.dart';
import 'claude_cfg_form.dart';

/// Zustand der ✦-Statuszeile (`.enh-run`-Klassen).
enum _RunTone { working, done, err, demo, plain }

class EnhanceFlowView extends ConsumerStatefulWidget {
  const EnhanceFlowView({super.key, required this.ctx, required this.flowId});

  final AiFlowCtx ctx;
  final String flowId;

  @override
  ConsumerState<EnhanceFlowView> createState() => _EnhanceFlowViewState();
}

class _EnhanceFlowViewState extends ConsumerState<EnhanceFlowView> {
  final TextEditingController _ans = TextEditingController();
  final TextEditingController _instruction = TextEditingController();
  final ScrollController _ansScroll = ScrollController();

  bool _copied = false;
  Timer? _copyTimer;
  AiCheckResult? _check;
  bool _cfgOpen = false;
  String _msg = '';
  AiMsgTone _msgTone = AiMsgTone.mut;

  /// countTokens-Verfeinerung (ersetzt das ≈-Label still, enhance.js:497-505).
  String? _refinedPrice;

  bool _running = false;
  String _runText = '';
  _RunTone _runTone = _RunTone.plain;
  Widget? _runExtra;

  @override
  void initState() {
    super.initState();
    _instruction.text = ref
        .read(enhCfgStoreProvider.notifier)
        .cfgFor(widget.flowId)
        .instruction;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refineTokens());
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _ans.dispose();
    _instruction.dispose();
    _ansScroll.dispose();
    super.dispose();
  }

  ProviderContainer get _container =>
      ProviderScope.containerOf(context, listen: false);

  AiFlow _flow() =>
      aiFlowById(buildAiFlows(_container, widget.ctx), widget.flowId);

  // ---- Preis-Verfeinerung über count_tokens -------------------------------

  Future<void> _refineTokens() async {
    final flow = _flow();
    if (flow.multi || flow.toggle) return;
    final cfg = _container.read(claudeCfgStoreProvider.notifier).current;
    if (!cfg.hasAccess) return;
    final prompt = aiPromptFor(_container, flow);
    final modelId =
        _container.read(enhCfgStoreProvider.notifier).cfgFor(flow.id).model;
    final n = await _container
        .read(claudeClientProvider)
        .countTokens(cfg, prompt, modelId);
    if (n == null || !mounted) return;
    final outTok = estOutTokens(n);
    setState(() {
      _refinedPrice =
          '${fmtTok(n)} Tok · ≈ ${fmtUsd(costOf(n, outTok, modelId))} · ${claudeModelOf(modelId ?? cfg.model).label}';
    });
  }

  // ---- Aktionen ------------------------------------------------------------

  Future<void> _copy() async {
    await Clipboard.setData(
        ClipboardData(text: aiPromptFor(_container, _flow())));
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _runCheck() {
    setState(() => _check = runAiCheck(_flow(), _ans.text, claudeClean));
  }

  void _doApply(String text) {
    final flow = _flow();
    try {
      final out = flow.run?.call(claudeClean(text)) ?? '';
      setState(() {
        _msg = '✓ $out';
        _msgTone = AiMsgTone.ok;
      });
      if (flow.done != null) {
        Timer(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          // Panel schließen, DANN navigieren — der Root-Kontext überlebt.
          final nav = Navigator.of(context, rootNavigator: true);
          nav.pop();
          flow.done!(nav.context);
        });
      }
    } catch (e) {
      setState(() {
        _msg = '✗ ${aiErrText(e)}';
        _msgTone = AiMsgTone.err;
      });
    }
  }

  Future<void> _loadFile() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'md', 'txt'],
      withData: true,
    );
    final bytes = res?.files.firstOrNull?.bytes;
    if (bytes == null || !mounted) return;
    _doApply(utf8.decode(bytes, allowMalformed: true));
  }

  // ---- ✦ Mit Claude (gptModal-Muster, s. Kopf-Kommentar) ------------------

  Future<void> _magic() async {
    final flow = _flow();
    final cfg = _container.read(claudeCfgStoreProvider.notifier).current;
    if (!cfg.ready) {
      showClaudeConfigModal(context, onChange: () {
        if (mounted) setState(() {});
      });
      return;
    }
    if (_running) {
      AiRunHandle.abort();
      return;
    }
    final cancel = AiCancelToken();
    AiRunHandle.current = cancel;
    final modelId =
        _container.read(enhCfgStoreProvider.notifier).cfgFor(flow.id).model;
    setState(() {
      _running = true;
      _runTone = _RunTone.working;
      _runText = 'Claude verbindet …';
      _runExtra = null;
      _ans.text = '';
      _msg = '';
    });
    try {
      final res = await _container.read(claudeClientProvider).run(
            cfg,
            aiPromptFor(_container, flow),
            onText: (t) {
              if (!mounted) return;
              _ans.text += t;
              if (_ansScroll.hasClients) {
                _ansScroll.jumpTo(_ansScroll.position.maxScrollExtent);
              }
            },
            onThink: (_) {
              if (mounted && _runTone == _RunTone.working && _runText == 'Claude verbindet …') {
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
            modelId: modelId,
          );
      if (!mounted) return;
      if (res.demo) {
        setState(() {
          _runTone = _RunTone.demo;
          _runText =
              'Demo abgeschlossen (${fmtTok(res.usage.input)} Tokens · ~${fmtUsd(res.cost)}). ';
          _runExtra = _inlink('Echten Zugang einrichten', () {
            showClaudeConfigModal(context, onChange: () {
              if (mounted) setState(() {});
            });
          });
        });
      } else {
        _ans.text = claudeClean(_ans.text);
        setState(() {
          _runTone = _RunTone.done;
          _runText =
              '✓ Fertig · ${fmtTok(res.usage.input)}→${fmtTok(res.usage.output)} Tokens · ${fmtUsd(res.cost)}';
        });
        _doApply(_ans.text);
      }
    } on AiAbortException {
      if (mounted) {
        setState(() {
          _runTone = _RunTone.plain;
          _runText = 'Abgebrochen.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _runTone = _RunTone.err;
          _runText = '✗ ${aiErrText(e)}';
        });
      }
    } finally {
      if (identical(AiRunHandle.current, cancel)) AiRunHandle.current = null;
      if (mounted) setState(() => _running = false);
    }
  }

  Widget _inlink(String label, VoidCallback onTap) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Builder(builder: (context) {
            final t = BookClothTokens.of(context);
            return Text(label,
                style: AppTextStyles.small.copyWith(
                  fontSize: 12.5,
                  color: t.accentInk,
                  decoration: TextDecoration.underline,
                ));
          }),
        ),
      );

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

    if (flow.toggle) return _toggleView(t, flow);

    // Preis-Label: lokale ≈-Schätzung, still verfeinert über count_tokens.
    String? price;
    if (ready) {
      try {
        final modelId =
            ref.read(enhCfgStoreProvider.notifier).cfgFor(flow.id).model;
        final est = claudeEstimate(aiPromptFor(_container, flow), modelId);
        price = _refinedPrice ??
            '≈ ${fmtUsd(est.cost)} · ${est.model.label}${demo ? ' · Demo' : ''}';
      } catch (_) {
        price = null;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fhead(t, flow, erzeugtPrefix: 'erzeugt: '),
        AiPaketStrip(flow: flow),
        // `.enh-actions`
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            EnhActButton(
              tooltip: 'Prompt in die Zwischenablage — fürs externe GPT (immer frei)',
              onPressed: _copy,
              child: Text(_copied ? '✔ kopiert' : '⧉ Kopieren'),
            ),
            if (!flow.multi)
              EnhActButton(
                magic: true,
                magicOff: !ready,
                tooltip: connected
                    ? 'Direkt mit Claude ausführen (Live-Kosten)'
                    : demo
                        ? 'Demo: Ablauf wird simuliert — es werden keine erfundenen Daten übernommen'
                        : 'Kein Zugang, Demo aus — klicken zum Einrichten',
                onPressed: _magic,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_running ? 'Abbrechen' : 'Mit Claude'),
                    if (price != null) ...[
                      const SizedBox(width: 6),
                      Opacity(
                        opacity: .95,
                        child: Text(
                          price,
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontFamilyFallback: AppFonts.fallback,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            EnhActButton(
              tooltip:
                  'Wie entsteht der Prompt? + aktueller Speicherstand dieser Stelle',
              onPressed: () => showAiFlowInfoDialog(context, _container, flow),
              child: const Text('ⓘ Info'),
            ),
            EnhActButton(
              tooltip:
                  'Diese Stelle einzeln konfigurieren (Modell, Zusatz-Anweisung)',
              onPressed: () => setState(() => _cfgOpen = !_cfgOpen),
              child: const Text('⚙'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // `.enh-steps` — der externe 3-Schritte-Weg (nur ohne echten Zugang).
        if (!flow.multi && !connected) _steps(t),
        // `.enh-run` — ✦-Statuszeile.
        if (_runText.isNotEmpty) _runBox(t),
        if (_check != null) AiCheckBox(_check!),
        if (_cfgOpen) _cfgView(t, flow),
        if (flow.multi) ...[
          Text(
            'Die Antwort umfasst mehrere Dateien. „⧉ Kopieren“ fürs externe GPT, dann importieren:',
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              small: true,
              variant: AppButtonVariant.primary,
              onPressed: () {
                final nav = Navigator.of(context, rootNavigator: true);
                nav.pop(); // Enhance.close()
                aiOpenMultiImport(
                  nav.context,
                  alertText:
                      'Diese Arbeit ist eingebaut — ihre Voranalyse wird mitgeliefert. Für eine neue Voranalyse eine eigene .tex-Arbeit importieren (Status → Arbeiten).',
                );
              },
              child: const Text('⭱ Analysen importieren (mehrere Dateien)'),
            ),
          ),
        ] else ...[
          TextField(
            controller: _ans,
            scrollController: _ansScroll,
            minLines: 7,
            maxLines: 16,
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 11.5,
              height: 1.5,
              color: t.ink,
            ),
            decoration: InputDecoration(
              hintText: flow.placeholder ?? 'Antwort hier einfügen …',
              hintStyle: TextStyle(
                fontFamily: AppFonts.mono,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 11.5,
                color: t.muted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              AppButton(
                small: true,
                tooltip:
                    'Eingefügte Antwort NUR prüfen (Format-Checker) — es wird nichts übernommen',
                onPressed: _runCheck,
                child: const Text('✓ Prüfen'),
              ),
              const SizedBox(width: 8),
              AppButton(
                small: true,
                variant: AppButtonVariant.primary,
                tooltip: 'Eingefügte Antwort übernehmen',
                onPressed: () {
                  if (_ans.text.trim().isEmpty) {
                    setState(() {
                      _msg = 'Antwort oben einfügen, dann „⭱ Übernehmen“.';
                      _msgTone = AiMsgTone.mut;
                    });
                    return;
                  }
                  _doApply(_ans.text);
                },
                child: const Text('⭱ Übernehmen'),
              ),
              const SizedBox(width: 8),
              AppButton(
                small: true,
                onPressed: _loadFile,
                child: const Text('Datei laden'),
              ),
              const SizedBox(width: 8),
              Expanded(child: AiMsgText(_msg, _msgTone)),
            ],
          ),
        ],
      ],
    );
  }

  /// Kopf `.enh-fhead`: Icon 26px, Titel + Scope-Chip, erzeugt-Zeile.
  Widget _fhead(BookClothTokens t, AiFlow flow, {String erzeugtPrefix = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(flow.icon, style: const TextStyle(fontSize: 26, height: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      flow.title,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontFamilyFallback: AppFonts.fallback,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.25,
                        color: t.ink,
                      ),
                    ),
                    AppChip(label: flow.scope, mini: true),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$erzeugtPrefix${flow.erzeugt}',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 12.5,
                    height: 1.45,
                    color: t.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `.enh-steps`: 1 ⧉ kopieren → 2 extern ausführen → 3 einfügen · prüfen …
  Widget _steps(BookClothTokens t) {
    Widget es(String n, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 15,
              height: 15,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: t.surface3),
              child: Text(
                n,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w700,
                  fontSize: 9.5,
                  height: 1,
                  color: t.ink2,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontFamilyFallback: AppFonts.fallback,
                  fontWeight: FontWeight.w500,
                  fontSize: 11.5,
                  height: 1.35,
                  color: t.muted,
                )),
          ],
        );
    Widget arrow() =>
        Text('→', style: TextStyle(fontSize: 11.5, color: t.borderStrong));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          es('1', '⧉ kopieren'),
          arrow(),
          es('2', 'extern ausführen (ChatGPT/Claude/…)'),
          arrow(),
          es('3', 'einfügen · ✓ prüfen · ⭱ übernehmen'),
        ],
      ),
    );
  }

  /// `.enh-run[.working|.done|.err|.demo]`.
  Widget _runBox(BookClothTokens t) {
    final (Color fg, Color bg, Color border) = switch (_runTone) {
      _RunTone.working => (t.ki, t.surface2, t.ki.mix(t.border, 42)),
      _RunTone.done => (t.good, t.goodSoft, t.good.mix(t.border, 40)),
      _RunTone.err => (t.bad, t.badSoft, t.bad.mix(t.border, 34)),
      _RunTone.demo => (t.ki, t.kiSoft, t.ki.mix(t.border, 40)),
      _RunTone.plain => (t.ink2, t.surface2, t.border),
    };
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            _runText,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontFamilyFallback: AppFonts.fallback,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              height: 1.4,
              color: fg,
            ),
          ),
          ?_runExtra,
          if (_runTone == _RunTone.demo)
            Text(
              ' für übernehmbare Ergebnisse.',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                height: 1.4,
                color: fg,
              ),
            ),
        ],
      ),
    );
  }

  /// ⚙-Ansicht (`_cfgHtml`/`_wireCfg`, enhance.js:628-641).
  Widget _cfgView(BookClothTokens t, AiFlow flow) {
    final store = ref.read(enhCfgStoreProvider.notifier);
    final cur = store.cfgFor(flow.id);
    final globalLabel =
        (ref.read(claudeCfgStoreProvider).value ?? ClaudeCfg.defaults)
            .modelDef()
            .label;
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.borderStrong),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Eyebrow('Diese Stelle einzeln konfigurieren'),
          const SizedBox(height: 8),
          Text('Modell für „${flow.title}“',
              style: AppTextStyles.small.copyWith(color: t.ink2)),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: cur.model ?? '',
              isExpanded: true,
              isDense: true,
              style: AppTextStyles.form.copyWith(fontSize: 13, color: t.ink),
              dropdownColor: t.surface,
              borderRadius: BorderRadius.circular(7),
              items: [
                DropdownMenuItem(
                    value: '', child: Text('— global ($globalLabel) —')),
                for (final m in kClaudeModels)
                  DropdownMenuItem(
                      value: m.id, child: Text('${m.label} · ${m.tier}')),
              ],
              onChanged: (v) {
                store.patch(flow.id, model: v ?? '');
                setState(() => _refinedPrice = null);
                _refineTokens();
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Zusatz-Anweisung an das Modell (optional — wird an den Prompt gehängt)',
            style: AppTextStyles.small.copyWith(color: t.ink2),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _instruction,
            minLines: 3,
            maxLines: 6,
            style: AppTextStyles.form.copyWith(fontSize: 13, color: t.ink),
            decoration: InputDecoration(
              hintText: 'z. B. „Sei knapper“ oder „nur die wichtigsten 3 pro Absatz“',
              hintStyle: AppTextStyles.form.copyWith(fontSize: 13, color: t.muted),
            ),
            onChanged: (v) => store.patch(flow.id, instruction: v),
          ),
        ],
      ),
    );
  }

  /// Stil-Check-Ansicht (`flow.toggle`, enhance.js:445-453).
  Widget _toggleView(BookClothTokens t, AiFlow flow) {
    final on = (ref.watch(studioPrefsCtlProvider).value ?? StudioPrefs.defaults)
        .styleCheck;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fhead(t, flow),
        AiPaketStrip(flow: flow),
        if (flow.reference != null) AiReferenceView(flow.reference!()),
        const SizedBox(height: 12),
        Row(
          children: [
            AppButton(
              variant: AppButtonVariant.primary,
              onPressed: () {
                // Toggle + Panel schließen (routeRefresh übernimmt Riverpod).
                ref
                    .read(studioPrefsCtlProvider.notifier)
                    .setStyleCheck(!on);
                Navigator.of(context, rootNavigator: true).pop();
              },
              child:
                  Text(on ? 'Stil-Check ausschalten' : 'Stil-Check einschalten'),
            ),
            const SizedBox(width: 8),
            EnhActButton(
              onPressed: () => showAiFlowInfoDialog(context, _container, flow),
              child: const Text('ⓘ Wie funktioniert das?'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ⓘ Info-Modal einer Stelle (`Enhance._info`, enhance.js:618-626)
// ---------------------------------------------------------------------------

void showAiFlowInfoDialog(
    BuildContext context, ProviderContainer container, AiFlow flow) {
  final prompt =
      flow.build != null && !flow.toggle ? aiPromptFor(container, flow) : null;
  showAppModal<void>(
    context,
    title: Text('ⓘ ${flow.title} — wie entsteht der Prompt?'),
    body: Builder(builder: (context) {
      final t = BookClothTokens.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flow.how, style: AppTextStyles.small.copyWith(color: t.ink2)),
          const SizedBox(height: 12),
          const Eyebrow('Aktueller Speicherstand dieser Stelle'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: t.surface2,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: flow.reference != null
                ? AiReferenceView(flow.reference!())
                : Text('—', style: AppTextStyles.small.copyWith(color: t.muted)),
          ),
          if (prompt != null) ...[
            const SizedBox(height: 12),
            const Eyebrow('Prompt-Vorschau (Anfang)'),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.surface2,
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  prompt.length > 900
                      ? '${prompt.substring(0, 900)}\n…'
                      : prompt,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 11,
                    height: 1.5,
                    color: t.ink2,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Jede KI-Stelle hat einen eigenen, spezifischen Prompt — über ⚙ pro Stelle mit einer Zusatz-Anweisung/Modell anpassbar.',
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
        ],
      );
    }),
  );
}
