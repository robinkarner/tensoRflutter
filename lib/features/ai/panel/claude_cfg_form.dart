/// ⚙ Claude-Zugangsformular — Port von `U._claudeCfgForm` (util.js:724-758)
/// und `U.claudeConfigModal` (util.js:759-767): EINE Quelle für den
/// Einrichtungs-Dialog UND die inline-Form der 🔑 Zugang-Ansicht.
/// Speichert bei jeder Änderung sofort (Write-Through in den globalen
/// KV-Key `claudeCfg` — E10, siehe client/claude_cfg.dart) und zeigt kurz
/// „✓ gespeichert“.
library;

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/modal.dart';
import '../client/claude_cfg.dart';
import '../client/claude_models.dart';

/// „GPT Magic — Zugang einrichten“ (`U.claudeConfigModal`).
void showClaudeConfigModal(BuildContext context, {VoidCallback? onChange}) {
  showAppModal<void>(
    context,
    title: const Text('GPT Magic — Zugang einrichten'),
    onClose: onChange,
    body: Builder(builder: (context) {
      final t = BookClothTokens.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Drei Wege zur Magie: '),
              TextSpan(
                  text: '⧉ extern kopieren',
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
              const TextSpan(text: ' (gratis, immer frei) · '),
              TextSpan(
                  text: '🔑 eigener Claude-Key',
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
              const TextSpan(text: ' (unten, bleibt lokal) · '),
              TextSpan(
                  text: '☁ Thesis-Studio AI-Space',
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
              const TextSpan(
                  text: ' (zentral über den Anbieter, ≈ 1 €/Durchlauf — die zugeteilte Adresse als Basis-URL eintragen, sobald verfügbar).'),
            ]),
            style: AppTextStyles.small.copyWith(color: t.muted),
          ),
          const SizedBox(height: 10),
          const ClaudeCfgForm(),
        ],
      );
    }),
  );
}

/// Das Formular (`.cc-grid`) — [onChange] läuft nach jeder Änderung.
class ClaudeCfgForm extends ConsumerStatefulWidget {
  const ClaudeCfgForm({super.key, this.onChange});

  final VoidCallback? onChange;

  @override
  ConsumerState<ClaudeCfgForm> createState() => _ClaudeCfgFormState();
}

class _ClaudeCfgFormState extends ConsumerState<ClaudeCfgForm> {
  late final TextEditingController _key;
  late final TextEditingController _max;
  late final TextEditingController _url;
  Timer? _stateTimer;
  bool _saved = false;
  final List<GestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    final c = ref.read(claudeCfgStoreProvider.notifier).current;
    _key = TextEditingController(text: c.apiKey);
    _max = TextEditingController(text: '${c.maxTokens}');
    _url = TextEditingController(text: c.baseUrl);
  }

  @override
  void dispose() {
    _stateTimer?.cancel();
    _key.dispose();
    _max.dispose();
    _url.dispose();
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  /// `save()` — den kompletten Formularstand speichern + „✓ gespeichert“.
  void _save() {
    final store = ref.read(claudeCfgStoreProvider.notifier);
    final cur = store.current;
    store.set(cur.copyWith(
      apiKey: _key.text,
      baseUrl: _url.text.trim().isEmpty ? kClaudeDefaultBaseUrl : _url.text.trim(),
      maxTokens: int.tryParse(_max.text) ?? kClaudeDefaultMaxTokens,
    ));
    setState(() => _saved = true);
    _stateTimer?.cancel();
    _stateTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _saved = false);
    });
    widget.onChange?.call();
  }

  void _patch(ClaudeCfg Function(ClaudeCfg) fn) {
    final store = ref.read(claudeCfgStoreProvider.notifier);
    store.set(fn(store.current));
    setState(() => _saved = true);
    _stateTimer?.cancel();
    _stateTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _saved = false);
    });
    widget.onChange?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final cfg = ref.watch(claudeCfgStoreProvider).value ?? ClaudeCfg.defaults;
    final narrow = MediaQuery.sizeOf(context).width <= 560;

    final labelStyle = TextStyle(
      fontFamily: AppFonts.ui,
      fontFamilyFallback: AppFonts.fallback,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      height: 1.3,
      color: t.ink2,
    );

    Widget field(String label, Widget input, {Widget? labelSuffix}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            labelSuffix == null
                ? Text(label, style: labelStyle)
                : Text.rich(TextSpan(children: [
                    TextSpan(text: label, style: labelStyle),
                    const TextSpan(text: ' '),
                    WidgetSpan(child: labelSuffix, alignment: PlaceholderAlignment.middle),
                  ])),
            const SizedBox(height: 4),
            input,
          ],
        );

    final modelSelect = DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: claudeModelOf(cfg.model).id,
        isExpanded: true,
        isDense: true,
        style: AppTextStyles.form.copyWith(fontSize: 13, color: t.ink),
        dropdownColor: t.surface,
        borderRadius: BorderRadius.circular(7),
        items: [
          for (final m in kClaudeModels)
            DropdownMenuItem(
              value: m.id,
              child: Text('${m.label} · ${m.tier} (\$${m.inUsd}/\$${m.outUsd})'),
            ),
        ],
        onChanged: (v) {
          if (v != null) _patch((c) => c.copyWith(model: v));
        },
      ),
    );

    final noteLink = TapGestureRecognizer()
      ..onTap = () => launcher.launchUrl(
          Uri.parse('https://console.anthropic.com/settings/keys'),
          mode: launcher.LaunchMode.externalApplication);
    _recognizers.add(noteLink);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        field(
          'Eigener API-Key',
          _input(t, _key,
              obscure: true,
              hint: 'sk-ant-… (bleibt in diesem Browser)',
              onChanged: (_) => _save()),
        ),
        const SizedBox(height: 10),
        // Modell + max. Antwort-Tokens nebeneinander (`.cc-grid` 1fr 1fr).
        if (narrow) ...[
          field('Modell', modelSelect),
          const SizedBox(height: 10),
          field(
            'max. Antwort-Tokens',
            _input(t, _max,
                keyboardType: TextInputType.number, onChanged: (_) => _save()),
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field('Modell', modelSelect)),
              const SizedBox(width: 12),
              Expanded(
                child: field(
                  'max. Antwort-Tokens',
                  _input(t, _max,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _save()),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        field(
          'Basis-URL',
          _input(t, _url, hint: kClaudeDefaultBaseUrl, onChanged: (_) => _save()),
          labelSuffix: Text('(eigener Proxy — hält den Key serverseitig)',
              style: AppTextStyles.small.copyWith(fontSize: 12, color: t.muted)),
        ),
        const SizedBox(height: 8),
        _check(
          t,
          value: cfg.deepThink,
          label: 'Tiefes Denken (adaptiv — nur Opus/Sonnet/Fable, etwas teurer & besser)',
          onChanged: (v) => _patch((c) => c.copyWith(deepThink: v)),
        ),
        _check(
          t,
          value: cfg.demo,
          label:
              'Demo-Modus, solange kein Zugang gesetzt ist (Knopf wirkt „verbunden“, Ablauf wird simuliert)',
          onChanged: (v) => _patch((c) => c.copyWith(demo: v)),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Der Zugang bleibt '),
            TextSpan(
                text: 'lokal in diesem Browser',
                style: TextStyle(fontWeight: FontWeight.w700, color: t.ink)),
            const TextSpan(
                text: ' und geht ausschließlich an die oben genannte Adresse. Eigenen Key: '),
            TextSpan(
              text: 'console.anthropic.com',
              recognizer: noteLink,
              style: TextStyle(color: t.accentInk),
            ),
            const TextSpan(text: '. '),
            if (_saved) TextSpan(text: '✓ gespeichert', style: TextStyle(color: t.good)),
          ]),
          style: AppTextStyles.small.copyWith(height: 1.6, color: t.muted),
        ),
      ],
    );
  }

  Widget _input(
    BookClothTokens t,
    TextEditingController ctl, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: ctl,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      autocorrect: false,
      enableSuggestions: false,
      style: AppTextStyles.form.copyWith(fontSize: 13, color: t.ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppTextStyles.form.copyWith(fontSize: 13, color: t.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      ),
    );
  }

  Widget _check(
    BookClothTokens t, {
    required bool value,
    required String label,
    required ValueChanged<bool> onChanged,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: t.accent,
                  side: BorderSide(color: t.borderStrong),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontFamilyFallback: AppFonts.fallback,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                    height: 1.4,
                    color: t.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
