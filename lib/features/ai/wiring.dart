/// K-3-Verdrahtung — füllt die in CONTRACTS §14 dokumentierten Anker:
///
///  * [QuellenGptHooks.magicBar] — die ✦-Magic-Bar „Mit Claude ausführen“
///    in den GPT-Dialogen der Quellen-Welt (✦ Durchlauf, 🤖 Ergänzung,
///    Referenzierungsdurchläufe der Status-Seite).
///  * [InstanzGenerateHook] — ↻ Recompile / ➕ Erstellen & Generieren der
///    ✎-Views-Verwaltung: EINE View direkt mit Claude kochen
///    (`viewGenerate`-Port, views_studio.js:2458-2480) — die Antwort läuft
///    über den normalen Instanzen-Import (Format-Checker inklusive).
///
/// Aufgerufen wird [wireAiHooks] von `wireAppSlots()` (lib/app_wiring.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/util/format.dart';
import '../../core/widgets/buttons.dart';
import '../../data/db/kv.dart';
import '../quellen/quellen.dart';
import '../studio/layout/dock_state.dart';
import '../studio/layout/studio_state.dart';
import '../studio/views/instanz_edit_modal.dart';
import '../studio/views/instanz_prompt.dart';
import 'client/claude_cfg.dart';
import 'client/claude_client.dart';
import 'flows/registry.dart';
import 'panel/claude_cfg_form.dart';
import 'widgets/ai_magic_bar.dart';

bool _wired = false;

/// Alle K-3-Anker füllen (idempotent).
void wireAiHooks() {
  if (_wired) return;
  _wired = true;

  // ✦ Magic-Bar in den Quellen-GPT-Dialogen (S-4-Anker).
  QuellenGptHooks.magicBar ??=
      (context, prompt, onAnswer) => AiMagicBar(prompt: prompt, onAnswer: onAnswer);

  // ↻ Recompile: übernimmt IMMER (ohne Zugang → Einrichten, wie
  // `viewGenerate`, views_studio.js:2459).
  InstanzGenerateHook.recompile ??= (context, def) {
    aiViewGenerate(context, def);
    return true;
  };

  // ➕ Erstellen & Generieren: nur bei Zugang/Demo direkt kochen
  // (views_studio.js:2440-2443) — sonst bleibt die View leer.
  InstanzGenerateHook.afterCreate ??= (context, def) {
    final container = ProviderScope.containerOf(context, listen: false);
    if (!container.read(claudeCfgStoreProvider.notifier).current.ready) return;
    aiViewGenerate(context, def);
  };
}

// ---------------------------------------------------------------------------
// ↻ EINE View (neu) generieren (`viewGenerate`-Port)
// ---------------------------------------------------------------------------

/// Direkt-Generierung EINER View. Ohne Zugang/Demo → Einrichten-Modal.
void aiViewGenerate(BuildContext context, DockDef def) {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(claudeCfgStoreProvider.notifier).current.ready) {
    showClaudeConfigModal(context);
    return;
  }
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ViewGenerateDialog(def: def, container: container),
  );
}

class _ViewGenerateDialog extends StatefulWidget {
  const _ViewGenerateDialog({required this.def, required this.container});

  final DockDef def;
  final ProviderContainer container;

  @override
  State<_ViewGenerateDialog> createState() => _ViewGenerateDialogState();
}

class _ViewGenerateDialogState extends State<_ViewGenerateDialog> {
  String _state = '⏳';
  final AiCancelToken _cancel = AiCancelToken();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final c = widget.container;
    final domain = c.read(studioDomainProvider);
    if (domain == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final snapshot = c.read(studioKvProvider).value ?? const <String, Object?>{};
    final prompt = instanzPromptFor(
      domain.ctx,
      [widget.def],
      materials: texMaterialsFrom(snapshot[KvKeys.srcExtras]),
    );
    final cfg = c.read(claudeCfgStoreProvider.notifier).current;
    try {
      final res = await c.read(claudeClientProvider).run(
            cfg,
            prompt,
            onUsage: (u) {
              if (mounted) setState(() => _state = fmtTok(u.output));
            },
            cancel: _cancel,
          );
      if (!mounted) return;
      if (res.demo) {
        Navigator.of(context).pop();
        _demoModal(res.cost);
        return;
      }
      aiImportInst(c, claudeClean(res.text));
      setState(() => _state = '✓');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } on AiAbortException {
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _errorModal(e is FormatException ? e.message : '$e');
    }
  }

  /// Demo-Modal (views_studio.js:2469-2472) — Texte wörtlich.
  void _demoModal(double cost) {
    final rootContext =
        Navigator.of(context, rootNavigator: true).context;
    final t = BookClothTokens.of(rootContext);
    showDialog<void>(
      context: rootContext,
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
              Text('${widget.def.label} — Demo abgeschlossen',
                  style: AppTextStyles.h3.copyWith(fontSize: 15.5, color: t.ink)),
              const SizedBox(height: 8),
              Text(
                'Mit echtem Zugang würde die View jetzt für die ganze Arbeit generiert und ersetzt (~${fmtEur(cost)}). Es wurden keine Daten übernommen.',
                style: AppTextStyles.small.copyWith(color: t.ink2),
              ),
              const SizedBox(height: 10),
              AppButton(
                small: true,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  showClaudeConfigModal(rootContext);
                },
                child: const Text('🔑 Zugang einrichten'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fehler-Modal (views_studio.js:2477-2479) — Texte wörtlich.
  void _errorModal(String message) {
    final rootContext =
        Navigator.of(context, rootNavigator: true).context;
    final t = BookClothTokens.of(rootContext);
    showDialog<void>(
      context: rootContext,
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
              Text('Generieren fehlgeschlagen',
                  style: AppTextStyles.h3.copyWith(fontSize: 15.5, color: t.ink)),
              const SizedBox(height: 8),
              Text(message, style: AppTextStyles.small.copyWith(color: t.ink2)),
              const SizedBox(height: 6),
              Text(
                'Alternative: ⧉ Prompt über das Views-Dock kopieren, extern ausführen, ⭱ einfügen.',
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

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BookClothTokens.radiusLg)),
      child: Container(
        width: 340,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('↻ ${widget.def.label}',
                style: AppTextStyles.h3.copyWith(fontSize: 15.5, color: t.ink)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _state,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: t.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _state == '✓'
                        ? 'Inhalte übernommen.'
                        : 'Claude generiert die View für die ganze Arbeit …',
                    style: AppTextStyles.small.copyWith(color: t.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                small: true,
                onPressed: _cancel.cancel,
                child: const Text('Abbrechen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
