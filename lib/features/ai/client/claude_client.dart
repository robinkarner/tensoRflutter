/// ClaudeAI-Client — Port von `js/claude.js`: einheitlicher Zugang zur
/// Anthropic Messages API für ALLE ✦-Pfade der App.
///
///  * `/v1/messages` mit `stream:true`, SSE selbst geparst (Blöcke an
///    `\n\n`, nur `data:`-Zeilen; Events message_start /
///    content_block_delta(text_delta|thinking_delta) / message_delta /
///    error — claude.js:151-179).
///  * `/v1/messages/count_tokens` verfeinert die lokale Schätzung
///    (scheitert LEISE mit null, claude.js:105-116).
///  * Header exakt wie das Original inkl.
///    `anthropic-dangerous-direct-browser-access: true` — auf dem
///    Web-Target nötig (CORS-Direktzugriff), nativ harmlos; für
///    1:1-Parität wird er immer gesendet (Dossier 08 §9.2).
///  * **Kein System-Prompt, keine History — immer Single-Turn.** Adaptives
///    Denken (`thinking:{type:"adaptive"}`) nur bei `deepThink` UND
///    adaptivem Modell.
///  * Demo-Modus: streamt den festen Demo-Text WORTWEISE mit 14 ms Takt,
///    zählt Usage hoch, importiert nie (claude.js:186-208).
///
/// Abbruch: [AiCancelToken] ist das AbortController-Pendant — `cancel()`
/// schließt den HTTP-Client, der Lauf endet mit [AiAbortException]
/// (Original: AbortError).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'claude_cfg.dart';
import 'claude_models.dart';

part 'claude_client.g.dart';

// ---------------------------------------------------------------------------
// Schätzung & Kosten (claude.js:57-85)
// ---------------------------------------------------------------------------

/// Schnelle lokale Schätzung (kein Netz): ~3,7 Zeichen/Token.
int estTokens(String? text) {
  final len = (text ?? '').length;
  return len == 0 ? 1 : (len / 3.7).ceil().clamp(1, 1 << 62);
}

/// Angenommene Antwortlänge für die Vorab-Abschätzung.
int estOutTokens(int inTok) => (inTok * 0.5).round().clamp(500, 4000);

/// Kosten in $ aus Token-Zahlen und Modell-Preisen.
double costOf(int inTok, int outTok, [String? modelId]) {
  final m = claudeModelOf(modelId);
  return (inTok / 1e6) * m.inUsd + (outTok / 1e6) * m.outUsd;
}

/// Vorab-Abschätzung für einen Prompt (`ClaudeAI.estimate`).
class ClaudeEstimate {
  final int inTok;
  final int outTok;
  final double cost;
  final ClaudeModelDef model;

  const ClaudeEstimate({
    required this.inTok,
    required this.outTok,
    required this.cost,
    required this.model,
  });
}

ClaudeEstimate claudeEstimate(String prompt, [String? modelId]) {
  final inTok = estTokens(prompt);
  final outTok = estOutTokens(inTok);
  return ClaudeEstimate(
    inTok: inTok,
    outTok: outTok,
    cost: costOf(inTok, outTok, modelId),
    model: claudeModelOf(modelId),
  );
}

// ---------------------------------------------------------------------------
// Lauf-Ergebnis, Usage, Abbruch
// ---------------------------------------------------------------------------

/// Laufende Token-Nutzung (`usage` der Callbacks).
class ClaudeUsage {
  final int input;
  final int output;

  const ClaudeUsage({this.input = 0, this.output = 0});
}

/// Ergebnis von [ClaudeClient.run].
class ClaudeRunResult {
  final String text;
  final ClaudeUsage usage;
  final double cost;
  final bool demo;

  const ClaudeRunResult({
    required this.text,
    required this.usage,
    required this.cost,
    this.demo = false,
  });
}

/// AbortError-Pendant — wird bei [AiCancelToken.cancel] geworfen.
class AiAbortException implements Exception {
  final String message = 'abgebrochen';

  @override
  String toString() => message;
}

/// AbortController-Pendant: `cancel()` bricht den laufenden Request ab.
class AiCancelToken {
  bool _cancelled = false;
  final List<void Function()> _hooks = [];

  bool get cancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final h in List.of(_hooks)) {
      try {
        h();
      } catch (_) {/* Aufräumen darf nie werfen */}
    }
  }

  void onCancel(void Function() hook) {
    if (_cancelled) {
      hook();
    } else {
      _hooks.add(hook);
    }
  }
}

// ---------------------------------------------------------------------------
// Der Client
// ---------------------------------------------------------------------------

class ClaudeClient {
  ClaudeClient({http.Client Function()? httpFactory})
      : _httpFactory = httpFactory ?? http.Client.new;

  final http.Client Function() _httpFactory;

  /// Header-Satz (claude.js:87-97) — `x-api-key` nur wenn gesetzt
  /// (beim Proxy entfällt er, der Key liegt serverseitig).
  Map<String, String> headers(ClaudeCfg cfg) => {
        'content-type': 'application/json',
        'anthropic-version': '2023-06-01',
        // Erlaubt den direkten Aufruf aus dem Browser (CORS/Direktzugriff).
        'anthropic-dangerous-direct-browser-access': 'true',
        if (cfg.apiKey.trim().isNotEmpty) 'x-api-key': cfg.apiKey.trim(),
      };

  Uri url(ClaudeCfg cfg, String path) {
    final base = (cfg.baseUrl.isEmpty ? kClaudeDefaultBaseUrl : cfg.baseUrl)
        .replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  /// Exakte Eingabe-Tokens über den count_tokens-Endpunkt — Zahl oder null
  /// (Fehler/kein Zugang scheitern LEISE, claude.js:105-116).
  Future<int?> countTokens(ClaudeCfg cfg, String prompt, [String? modelId]) async {
    if (!cfg.ready) return null;
    final client = _httpFactory();
    try {
      final r = await client.post(
        url(cfg, '/v1/messages/count_tokens'),
        headers: headers(cfg),
        body: jsonEncode({
          'model': modelId ?? cfg.model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );
      if (r.statusCode < 200 || r.statusCode >= 300) return null;
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      final n = d is Map ? d['input_tokens'] : null;
      return n is num ? n.toInt() : null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Kern: Prompt streamen (claude.js:121-182). [modelId] übersteuert das
  /// globale Modell (per-Flow-⚙ — das Original setzt dafür kurzzeitig die
  /// globale Config um und stellt sie im `finally` zurück, enhance.js:827/
  /// 879; der Parameter ist das seiteneffektfreie Pendant).
  Future<ClaudeRunResult> run(
    ClaudeCfg cfg,
    String prompt, {
    void Function(String chunk)? onText,
    void Function(String chunk)? onThink,
    void Function(ClaudeUsage usage)? onUsage,
    AiCancelToken? cancel,
    String? modelId,
  }) async {
    if (!cfg.ready) {
      throw const FormatException('Kein Claude-Zugang hinterlegt — erst einrichten (⚙).');
    }
    // Demo-Modus: kein echter Zugang → Ablauf simulieren (Streaming +
    // Kosten), OHNE erfundene Daten zu importieren.
    if (!cfg.hasAccess && cfg.isDemo) {
      return _runDemo(cfg, prompt,
          onText: onText, onUsage: onUsage, cancel: cancel, modelId: modelId);
    }

    final model = modelId ?? cfg.model;
    final m = claudeModelOf(model);
    final body = <String, Object?>{
      'model': model,
      'max_tokens': cfg.maxTokens < 1024 ? 1024 : cfg.maxTokens,
      'stream': true,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      if (cfg.deepThink && m.adaptive) 'thinking': {'type': 'adaptive'},
    };

    final client = _httpFactory();
    cancel?.onCancel(client.close);
    try {
      http.StreamedResponse res;
      try {
        final req = http.Request('POST', url(cfg, '/v1/messages'))
          ..headers.addAll(headers(cfg))
          ..body = jsonEncode(body);
        res = await client.send(req);
      } catch (e) {
        if (cancel?.cancelled ?? false) throw AiAbortException();
        throw FormatException('Netzwerkfehler — Adresse/Verbindung prüfen ($e).');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        String detail = '';
        try {
          final t = await res.stream.bytesToString();
          detail = _errMsg(res.statusCode, t);
        } catch (_) {}
        throw FormatException(detail.isNotEmpty ? detail : _errMsg(res.statusCode, ''));
      }

      // SSE-Parsing wie im Original: Puffer, Blöcke an '\n\n' trennen, nur
      // 'data:'-Zeilen auswerten; '[DONE]' ignorieren.
      var buf = '';
      var text = '';
      var usage = const ClaudeUsage();
      final stream = res.stream.transform(utf8.decoder);
      try {
        await for (final chunk in stream) {
          if (cancel?.cancelled ?? false) throw AiAbortException();
          buf += chunk;
          int sep;
          while ((sep = buf.indexOf('\n\n')) >= 0) {
            final block = buf.substring(0, sep);
            buf = buf.substring(sep + 2);
            String? dataLine;
            for (final l in block.split('\n')) {
              if (l.startsWith('data:')) {
                dataLine = l;
                break;
              }
            }
            if (dataLine == null) continue;
            final payload = dataLine.substring(5).trim();
            if (payload.isEmpty || payload == '[DONE]') continue;
            Object? ev;
            try {
              ev = jsonDecode(payload);
            } catch (_) {
              continue;
            }
            if (ev is! Map) continue;
            final type = ev['type'];
            if (type == 'message_start') {
              final u = ev['message'] is Map ? (ev['message'] as Map)['usage'] : null;
              if (u is Map) {
                final inTok = u['input_tokens'];
                usage = ClaudeUsage(
                  input: inTok is num ? inTok.toInt() : 0,
                  output: usage.output,
                );
                onUsage?.call(usage);
              }
            } else if (type == 'content_block_delta') {
              final delta = ev['delta'];
              if (delta is Map && delta['type'] == 'text_delta') {
                final tx = '${delta['text'] ?? ''}';
                text += tx;
                onText?.call(tx);
              } else if (delta is Map && delta['type'] == 'thinking_delta') {
                onThink?.call('${delta['thinking'] ?? ''}');
              }
            } else if (type == 'message_delta') {
              final u = ev['usage'];
              if (u is Map) {
                final outTok = u['output_tokens'];
                usage = ClaudeUsage(
                  input: usage.input,
                  output: outTok is num ? outTok.toInt() : usage.output,
                );
                onUsage?.call(usage);
              }
            } else if (type == 'error') {
              final err = ev['error'];
              final msg = err is Map ? err['message'] : null;
              throw FormatException(
                  msg is String && msg.isNotEmpty ? msg : 'Claude meldete einen Stream-Fehler.');
            }
          }
        }
      } on AiAbortException {
        rethrow;
      } catch (e) {
        // client.close() beendet den Stream mit einem Fehler → AbortError.
        if (cancel?.cancelled ?? false) throw AiAbortException();
        if (e is FormatException) rethrow;
        throw FormatException('Netzwerkfehler — Adresse/Verbindung prüfen ($e).');
      }
      if (cancel?.cancelled ?? false) throw AiAbortException();
      return ClaudeRunResult(
        text: text,
        usage: usage,
        cost: costOf(usage.input, usage.output, model),
      );
    } finally {
      client.close();
    }
  }

  /// Simulierter Lauf für den Demo-Modus (claude.js:186-208) — Text exakt.
  Future<ClaudeRunResult> _runDemo(
    ClaudeCfg cfg,
    String prompt, {
    void Function(String chunk)? onText,
    void Function(ClaudeUsage usage)? onUsage,
    AiCancelToken? cancel,
    String? modelId,
  }) async {
    final inTok = estTokens(prompt);
    const demoText = '✦ Demo-Modus — so liefe die Anfrage mit echtem Zugang:\n'
        '\n'
        'Der Prompt geht direkt an Claude, die Antwort wird hier live gestreamt und automatisch übernommen — mit echter Token- und Kostenabrechnung.\n'
        '\n'
        'Für ECHTE, übernehmbare Ergebnisse: ⚙ Zugang einrichten (eigener API-Key oder zentraler Proxy). „⧉ Prompt“ für ein externes GPT geht jederzeit — auch ohne Zugang.';
    onUsage?.call(ClaudeUsage(input: inTok));
    final words = demoText.split(' ');
    var out = 0;
    for (var i = 0; i < words.length; i++) {
      if (cancel?.cancelled ?? false) throw AiAbortException();
      onText?.call(words[i] + (i < words.length - 1 ? ' ' : ''));
      out += (words[i].length / 3.7).round().clamp(1, 1 << 30);
      onUsage?.call(ClaudeUsage(input: inTok, output: out));
      await Future<void>.delayed(const Duration(milliseconds: 14));
    }
    final outTok = estTokens(demoText);
    return ClaudeRunResult(
      text: demoText,
      usage: ClaudeUsage(input: inTok, output: outTok),
      cost: costOf(inTok, outTok, modelId ?? cfg.model),
      demo: true,
    );
  }

  /// Fehler-Mapping (claude.js:210-222) — Texte wörtlich.
  String _errMsg(int status, String bodyText) {
    var apiMsg = '';
    try {
      final d = jsonDecode(bodyText);
      final err = d is Map ? d['error'] : null;
      final m = err is Map ? err['message'] : null;
      if (m is String) apiMsg = m;
    } catch (_) {}
    const map = <int, String>{
      401: 'Zugang abgelehnt (401) — API-Key falsch oder fehlt.',
      403: 'Kein Zugriff (403) — Key/Endpunkt prüfen.',
      404: 'Endpunkt nicht gefunden (404) — Basis-URL prüfen.',
      429: 'Zu viele Anfragen / Kontingent erschöpft (429).',
      529: 'Claude überlastet (529) — gleich erneut versuchen.',
    };
    final base = map[status] ?? (status != 0 ? 'Fehler $status.' : 'Unbekannter Fehler.');
    return apiMsg.isNotEmpty ? '$base $apiMsg' : base;
  }
}

/// Antwort säubern: einen umschließenden ```-Codeblock entfernen
/// (claude.js:226-234) — die JSON-/Markdown-Importer wollen den nackten
/// Inhalt. Sonst unverändert.
String claudeClean(String? text) {
  final t = (text ?? '').trim();
  final m = RegExp(r'^```[a-zA-Z0-9]*\s*\n([\s\S]*?)\n```$').firstMatch(t);
  if (m != null) return m.group(1)!.trim();
  // Nur EIN Codeblock irgendwo? (Claude rahmt manchmal mit Vor-/Nachsatz)
  final all = RegExp(r'```[a-zA-Z0-9]*\s*\n([\s\S]*?)\n```').allMatches(t).toList();
  if (all.length == 1) return all[0].group(1)!.trim();
  return t;
}

/// Client-Provider — Tests übersteuern mit einer Fake-http-Factory.
@Riverpod(keepAlive: true)
ClaudeClient claudeClient(Ref ref) => ClaudeClient();
