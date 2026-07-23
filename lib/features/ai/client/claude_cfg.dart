/// Claude-Zugangs-Konfiguration + per-Flow-Config — Ports von
/// `ClaudeAI.cfg()/setCfg()` (claude.js:32-41) und `Enhance.cfg()/setCfg()`
/// (enhance.js:42-47).
///
/// Beide Keys sind GLOBAL (nicht projekt-gescoped): `claudeCfg` und `enhCfg`
/// stehen bewusst NICHT in PROJECT_KEYS — der Zugang gilt über alle
/// Arbeiten hinweg (claude.js:18-19).
///
/// **E10 (Key-Ablage):** Das Original legt den API-Key im KLARTEXT in
/// localStorage ab. Der Port übernimmt die Parität bewusst — der Key liegt
/// im Klartext in der lokalen Drift-DB (globaler KV-Key `claudeCfg`,
/// Verhalten identisch: global, projektübergreifend, sofortiges Speichern
/// bei Eingabe). `flutter_secure_storage` ist die dokumentierte Ausbaustufe
/// (BAUPLAN E10); ein Wechsel bräuchte nur diesen Store.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/db/kv.dart';
import 'claude_models.dart';

part 'claude_cfg.g.dart';

// ---------------------------------------------------------------------------
// ClaudeCfg
// ---------------------------------------------------------------------------

/// Die effektive Konfiguration (Defaults + gespeicherte Abweichungen).
class ClaudeCfg {
  final String baseUrl;
  final String model;
  final int maxTokens;
  final bool deepThink;

  /// Demo-Modus solange kein Zugang gesetzt ist (Default AN — nur explizites
  /// `false` schaltet ihn ab, `ClaudeAI.isDemo`, claude.js:52).
  final bool demo;
  final String apiKey;

  const ClaudeCfg({
    this.baseUrl = kClaudeDefaultBaseUrl,
    this.model = kClaudeDefaultModel,
    this.maxTokens = kClaudeDefaultMaxTokens,
    this.deepThink = false,
    this.demo = true,
    this.apiKey = '',
  });

  static const defaults = ClaudeCfg();

  /// Tolerant wie `{...DEFAULTS, ...(raw || {})}` — falsche Typen fallen
  /// auf die Defaults zurück.
  factory ClaudeCfg.fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    String str(Object? v, String fb) => v is String && v.isNotEmpty ? v : fb;
    final maxRaw = raw['maxTokens'];
    final max = maxRaw is num
        ? maxRaw.toInt()
        : int.tryParse('${raw['maxTokens'] ?? ''}') ?? kClaudeDefaultMaxTokens;
    return ClaudeCfg(
      baseUrl: str(raw['baseUrl'], kClaudeDefaultBaseUrl),
      model: str(raw['model'], kClaudeDefaultModel),
      maxTokens: max > 0 ? max : kClaudeDefaultMaxTokens,
      deepThink: raw['deepThink'] == true,
      // Original: `demo !== false` — nur explizites false zählt als aus.
      demo: raw['demo'] != false,
      apiKey: raw['apiKey'] is String ? raw['apiKey'] as String : '',
    );
  }

  /// Persistenzform — wie das Original wird der KOMPLETTE gemergte Zustand
  /// gespeichert (claude.js:36-41).
  Map<String, Object?> toJson() => {
        'baseUrl': baseUrl,
        'model': model,
        'maxTokens': maxTokens,
        'deepThink': deepThink,
        'demo': demo,
        if (apiKey.isNotEmpty) 'apiKey': apiKey,
      };

  ClaudeCfg copyWith({
    String? baseUrl,
    String? model,
    int? maxTokens,
    bool? deepThink,
    bool? demo,
    String? apiKey,
  }) =>
      ClaudeCfg(
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        maxTokens: maxTokens ?? this.maxTokens,
        deepThink: deepThink ?? this.deepThink,
        demo: demo ?? this.demo,
        apiKey: apiKey ?? this.apiKey,
      );

  /// Aktives Modell-Objekt ([modelId] übersteuert — per-Flow-Config).
  ClaudeModelDef modelDef([String? modelId]) => claudeModelOf(modelId ?? model);

  /// Echter Zugang? Eigener Key ODER eigene Basis-URL (Proxy hält den Key) —
  /// `ClaudeAI.hasAccess` (claude.js:45-48).
  bool get hasAccess =>
      apiKey.trim().isNotEmpty ||
      (baseUrl.isNotEmpty && baseUrl != kClaudeDefaultBaseUrl);

  /// Demo-Modus: kein echter Zugang, aber „als wäre verbunden“.
  bool get isDemo => !hasAccess && demo;

  /// Knopf „aktiv“? Echter Zugang ODER Demo.
  bool get ready => hasAccess || isDemo;
}

/// Store des globalen `claudeCfg`-Keys mit Write-Through (E10 s. oben).
@Riverpod(keepAlive: true)
class ClaudeCfgStore extends _$ClaudeCfgStore {
  @override
  Future<ClaudeCfg> build() async =>
      ClaudeCfg.fromJson(await ref.watch(kvStoreProvider).getJson(KvKeys.claudeCfg));

  /// Aktueller Wert, synchron (vor dem ersten Laden: Defaults).
  ClaudeCfg get current => state.value ?? ClaudeCfg.defaults;

  /// `ClaudeAI.setCfg(patch)` — speichert den gemergten Zustand sofort.
  void set(ClaudeCfg next) {
    state = AsyncData(next);
    ref.read(kvStoreProvider).setJson(KvKeys.claudeCfg, next.toJson());
  }
}

// ---------------------------------------------------------------------------
// Enhance-Konfiguration je Stelle (⚙: Modell + Zusatz-Anweisung)
// ---------------------------------------------------------------------------

/// per-Flow-Config `{model?, instruction?}` (`Enhance.cfg`, enhance.js:42).
class EnhFlowCfg {
  final String? model;
  final String instruction;

  const EnhFlowCfg({this.model, this.instruction = ''});
}

/// Store des globalen `enhCfg`-Keys (`{"<flowId>": {model, instruction}}`).
@Riverpod(keepAlive: true)
class EnhCfgStore extends _$EnhCfgStore {
  @override
  Future<Map<String, Object?>> build() async {
    final v = await ref.watch(kvStoreProvider).getJson(KvKeys.enhCfg);
    return v is Map ? v.map((k, val) => MapEntry('$k', val)) : const {};
  }

  Map<String, Object?> get _all => state.value ?? const {};

  /// `Enhance.cfg(id)` — leeres Objekt, wenn nichts gespeichert.
  EnhFlowCfg cfgFor(String flowId) {
    final raw = _all[flowId];
    if (raw is! Map) return const EnhFlowCfg();
    final model = raw['model'];
    final instruction = raw['instruction'];
    return EnhFlowCfg(
      model: model is String && model.isNotEmpty ? model : null,
      instruction: instruction is String ? instruction : '',
    );
  }

  /// `Enhance.setCfg(id, patch)` — Patch-Merge + Write-Through.
  void patch(String flowId, {Object? model = _sentinel, String? instruction}) {
    final cur = _all[flowId];
    final entry = <String, Object?>{
      ...(cur is Map ? cur.map((k, v) => MapEntry('$k', v)) : const {}),
    };
    if (!identical(model, _sentinel)) {
      // Leere Auswahl = zurück auf „global“ (Original speichert undefined).
      if (model is String && model.isNotEmpty) {
        entry['model'] = model;
      } else {
        entry.remove('model');
      }
    }
    if (instruction != null) entry['instruction'] = instruction;
    final next = {..._all, flowId: entry};
    state = AsyncData(next);
    ref.read(kvStoreProvider).setJson(KvKeys.enhCfg, next);
  }

  static const _sentinel = Object();
}

// ---------------------------------------------------------------------------
// Zugangs-Status (`Enhance.accessInfo`, enhance.js:29-40)
// ---------------------------------------------------------------------------

/// Punkt-Zustand des Status: on (grün) / off / demo (gelb).
enum AiAccessDot { on, off, demo }

/// Zugangs-Status auf EINEN Blick — Labels wörtlich.
class AiAccessInfo {
  /// 'extern' | 'space' | 'key' | 'demo'.
  final String mode;
  final String label;
  final AiAccessDot dot;

  const AiAccessInfo({required this.mode, required this.label, required this.dot});
}

AiAccessInfo aiAccessInfo(ClaudeCfg cfg) {
  if (cfg.hasAccess) {
    final viaProxy = cfg.apiKey.trim().isEmpty;
    return viaProxy
        ? const AiAccessInfo(mode: 'space', label: 'AI-Space verbunden', dot: AiAccessDot.on)
        : AiAccessInfo(
            mode: 'key',
            label: 'verbunden · ${cfg.modelDef().label}',
            dot: AiAccessDot.on,
          );
  }
  if (cfg.isDemo) {
    return const AiAccessInfo(mode: 'demo', label: 'Demo-Modus', dot: AiAccessDot.demo);
  }
  return const AiAccessInfo(mode: 'extern', label: 'nur ⧉ extern', dot: AiAccessDot.off);
}
