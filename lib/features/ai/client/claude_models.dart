/// Modell-Katalog + Defaults des Claude-Clients — Port der Konstanten
/// `ClaudeAI.DEFAULTS` / `ClaudeAI.MODELS` (claude.js:20-30).
///
/// Die Preise ($/1 Mio Tokens) sind sichtbarer Teil der UI (Magic-Knöpfe,
/// ⚙-Selects) und werden EXAKT gespiegelt; `adaptive` = unterstützt
/// adaptives Denken (`thinking:{type:"adaptive"}`).
library;

/// Ein Eintrag der Preisliste.
class ClaudeModelDef {
  final String id;
  final String label;
  final String tier;

  /// $ / 1 Mio Eingabe-Tokens.
  final num inUsd;

  /// $ / 1 Mio Ausgabe-Tokens.
  final num outUsd;
  final bool adaptive;

  const ClaudeModelDef({
    required this.id,
    required this.label,
    required this.tier,
    required this.inUsd,
    required this.outUsd,
    required this.adaptive,
  });
}

/// `ClaudeAI.MODELS` — Reihenfolge trägt Semantik (MODELS[0] ist der
/// Fallback in `ClaudeAI.model()`).
const List<ClaudeModelDef> kClaudeModels = [
  ClaudeModelDef(id: 'claude-opus-4-8', label: 'Opus 4.8', tier: 'Höchste Qualität', inUsd: 5, outUsd: 25, adaptive: true),
  ClaudeModelDef(id: 'claude-sonnet-5', label: 'Sonnet 5', tier: 'Schnell & günstig', inUsd: 3, outUsd: 15, adaptive: true),
  ClaudeModelDef(id: 'claude-haiku-4-5', label: 'Haiku 4.5', tier: 'Am günstigsten', inUsd: 1, outUsd: 5, adaptive: false),
  ClaudeModelDef(id: 'claude-opus-4-7', label: 'Opus 4.7', tier: 'Vorgänger', inUsd: 5, outUsd: 25, adaptive: true),
  ClaudeModelDef(id: 'claude-fable-5', label: 'Fable 5', tier: 'Maximal', inUsd: 10, outUsd: 50, adaptive: true),
];

/// `ClaudeAI.DEFAULTS` (claude.js:20).
const String kClaudeDefaultBaseUrl = 'https://api.anthropic.com';
const String kClaudeDefaultModel = 'claude-opus-4-8';
const int kClaudeDefaultMaxTokens = 6000;

/// Modell-Objekt zu einer id — Fallback ist immer `MODELS[0]`
/// (`ClaudeAI.model`, claude.js:42).
ClaudeModelDef claudeModelOf(String? id) {
  for (final m in kClaudeModels) {
    if (m.id == id) return m;
  }
  return kClaudeModels[0];
}
