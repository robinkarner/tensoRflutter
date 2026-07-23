/// K-3-Client-Tests: Token-/Kosten-Schätzung, Preisformate (Konsument),
/// `clean()`-Codeblock-Entferner, SSE-Parsing des `/v1/messages`-Streams,
/// Fehler-Mapping, Demo-Modus und Konfigurations-Semantik
/// (hasAccess/isDemo/ready) — alles gegen die claude.js-Vorlage.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thesor/features/ai/ai.dart';

/// SSE-Antwort aus Events bauen (Blöcke an `\n\n`, `data:`-Zeilen).
String sse(List<Map<String, Object?>> events) =>
    events.map((e) => 'data: ${jsonEncode(e)}\n\n').join();

ClaudeClient clientWith(MockClient mock) =>
    ClaudeClient(httpFactory: () => mock);

void main() {
  group('Schätzung & Kosten (claude.js:57-85)', () {
    test('estTokens: ceil(len/3.7), min 1', () {
      expect(estTokens(''), 1);
      expect(estTokens('a' * 37), 10);
      expect(estTokens('a' * 38), 11);
    });

    test('estOutTokens: min 500, max 4000, sonst in/2', () {
      expect(estOutTokens(100), 500);
      expect(estOutTokens(2000), 1000);
      expect(estOutTokens(20000), 4000);
    });

    test('costOf rechnet mit Modellpreisen; unbekannte id → MODELS[0]', () {
      // Opus 4.8: $5 in / $25 out.
      expect(costOf(1000000, 1000000, 'claude-opus-4-8'), 30.0);
      // Haiku 4.5: $1/$5.
      expect(costOf(2000000, 0, 'claude-haiku-4-5'), 2.0);
      // Fallback = Opus 4.8.
      expect(costOf(1000000, 0, 'gibt-es-nicht'), 5.0);
    });

    test('Modell-Katalog: 5 Modelle mit exakten Preisen', () {
      expect(kClaudeModels.map((m) => m.id), [
        'claude-opus-4-8',
        'claude-sonnet-5',
        'claude-haiku-4-5',
        'claude-opus-4-7',
        'claude-fable-5',
      ]);
      final fable = claudeModelOf('claude-fable-5');
      expect((fable.label, fable.tier, fable.inUsd, fable.outUsd, fable.adaptive),
          ('Fable 5', 'Maximal', 10, 50, true));
      expect(claudeModelOf('claude-haiku-4-5').adaptive, isFalse);
    });
  });

  group('ClaudeCfg (claude.js:32-55)', () {
    test('fromJson tolerant, demo nur bei explizitem false aus', () {
      expect(ClaudeCfg.fromJson(null).demo, isTrue);
      expect(ClaudeCfg.fromJson({'demo': false}).demo, isFalse);
      expect(ClaudeCfg.fromJson({'maxTokens': '8000'}).maxTokens, 8000);
      expect(ClaudeCfg.fromJson({'maxTokens': -3}).maxTokens, 6000);
    });

    test('hasAccess: Key ODER abweichende Basis-URL (Proxy)', () {
      expect(const ClaudeCfg().hasAccess, isFalse);
      expect(const ClaudeCfg(apiKey: ' sk-ant-x ').hasAccess, isTrue);
      expect(const ClaudeCfg(baseUrl: 'https://proxy.example').hasAccess, isTrue);
    });

    test('isDemo/ready-Kaskade', () {
      const ohneAlles = ClaudeCfg(demo: false);
      expect(ohneAlles.isDemo, isFalse);
      expect(ohneAlles.ready, isFalse);
      const nurDemo = ClaudeCfg();
      expect(nurDemo.isDemo, isTrue);
      expect(nurDemo.ready, isTrue);
      const mitKey = ClaudeCfg(apiKey: 'sk');
      expect(mitKey.isDemo, isFalse);
      expect(mitKey.ready, isTrue);
    });

    test('accessInfo-Labels wörtlich', () {
      expect(aiAccessInfo(const ClaudeCfg(apiKey: 'sk')).label,
          'verbunden · Opus 4.8');
      expect(aiAccessInfo(const ClaudeCfg(baseUrl: 'https://p.example')).label,
          'AI-Space verbunden');
      expect(aiAccessInfo(const ClaudeCfg()).label, 'Demo-Modus');
      expect(aiAccessInfo(const ClaudeCfg(demo: false)).label, 'nur ⧉ extern');
    });
  });

  group('clean (claude.js:226-234)', () {
    test('umschließender Codeblock wird entfernt', () {
      expect(claudeClean('```json\n{"a":1}\n```'), '{"a":1}');
    });

    test('EIN eingebetteter Block mit Vor-/Nachsatz → nur der Block', () {
      expect(claudeClean('Hier: \n```\n{"a":1}\n```\nGruß'), '{"a":1}');
    });

    test('mehrere Blöcke/kein Block → unverändert (getrimmt)', () {
      const two = 'a\n```\nx\n```\nb\n```\ny\n```';
      expect(claudeClean(two), two);
      expect(claudeClean('  plain  '), 'plain');
    });
  });

  group('run — SSE-Streaming', () {
    test('parst message_start/content_block_delta/message_delta', () async {
      late http.Request captured;
      final mock = MockClient.streaming((request, bodyStream) async {
        captured = request as http.Request;
        final body = sse([
          {
            'type': 'message_start',
            'message': {
              'usage': {'input_tokens': 12},
            },
          },
          {
            'type': 'content_block_delta',
            'delta': {'type': 'text_delta', 'text': 'Hallo '},
          },
          {
            'type': 'content_block_delta',
            'delta': {'type': 'thinking_delta', 'thinking': 'hmm'},
          },
          {
            'type': 'content_block_delta',
            'delta': {'type': 'text_delta', 'text': 'Welt'},
          },
          {
            'type': 'message_delta',
            'usage': {'output_tokens': 7},
          },
        ]);
        return http.StreamedResponse(
            Stream.value(utf8.encode(body)), 200);
      });
      final chunks = <String>[];
      final thinks = <String>[];
      final usages = <ClaudeUsage>[];
      const cfg = ClaudeCfg(apiKey: 'sk-test', model: 'claude-haiku-4-5');
      final res = await clientWith(mock).run(
        cfg,
        'Prompt',
        onText: chunks.add,
        onThink: thinks.add,
        onUsage: usages.add,
      );
      expect(res.text, 'Hallo Welt');
      expect(chunks, ['Hallo ', 'Welt']);
      expect(thinks, ['hmm']);
      expect(res.usage.input, 12);
      expect(res.usage.output, 7);
      expect(res.demo, isFalse);
      // Kosten aus ECHTEN Usage-Zahlen mit dem Modell der Config.
      expect(res.cost, closeTo(costOf(12, 7, 'claude-haiku-4-5'), 1e-12));
      // Header-Satz exakt (inkl. dangerous-direct-browser-access).
      expect(captured.headers['anthropic-version'], '2023-06-01');
      expect(captured.headers['anthropic-dangerous-direct-browser-access'], 'true');
      expect(captured.headers['x-api-key'], 'sk-test');
      final sent = jsonDecode(captured.body) as Map;
      expect(sent['stream'], true);
      expect(sent['model'], 'claude-haiku-4-5');
      expect(sent['max_tokens'], 6000);
      // Haiku ist nicht adaptiv — kein thinking-Feld.
      expect(sent.containsKey('thinking'), isFalse);
      // Single-Turn ohne System-Prompt.
      expect((sent['messages'] as List).length, 1);
      expect(sent.containsKey('system'), isFalse);
    });

    test('deepThink + adaptives Modell → thinking:{type:adaptive}', () async {
      late String body;
      final mock = MockClient.streaming((request, bodyStream) async {
        body = (request as http.Request).body;
        return http.StreamedResponse(Stream.value(utf8.encode(sse([]))), 200);
      });
      const cfg = ClaudeCfg(apiKey: 'sk', deepThink: true);
      await clientWith(mock).run(cfg, 'x');
      expect((jsonDecode(body) as Map)['thinking'], {'type': 'adaptive'});
    });

    test('Fehler-Map 401 wörtlich + API-Detail', () async {
      final mock = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'error': {'message': 'invalid x-api-key'},
          }))),
          401,
        );
      });
      const cfg = ClaudeCfg(apiKey: 'sk');
      await expectLater(
        clientWith(mock).run(cfg, 'x'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            'Zugang abgelehnt (401) — API-Key falsch oder fehlt. invalid x-api-key')),
      );
    });

    test('error-Event im Stream wirft mit Claude-Meldung', () async {
      final mock = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(sse([
            {
              'type': 'error',
              'error': {'message': 'Overloaded'},
            },
          ]))),
          200,
        );
      });
      const cfg = ClaudeCfg(apiKey: 'sk');
      await expectLater(
        clientWith(mock).run(cfg, 'x'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', 'Overloaded')),
      );
    });

    test('ohne Zugang und Demo aus → Original-Meldung', () async {
      const cfg = ClaudeCfg(demo: false);
      await expectLater(
        ClaudeClient().run(cfg, 'x'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            'Kein Claude-Zugang hinterlegt — erst einrichten (⚙).')),
      );
    });
  });

  group('Demo-Modus (claude.js:186-208)', () {
    test('streamt wortweise, importiert nie (demo:true), Kosten simuliert',
        () async {
      const cfg = ClaudeCfg(); // kein Zugang, Demo an
      final chunks = <String>[];
      ClaudeUsage? last;
      final res = await ClaudeClient().run(
        cfg,
        'kurzer Prompt',
        onText: chunks.add,
        onUsage: (u) => last = u,
      );
      expect(res.demo, isTrue);
      expect(res.text, startsWith('✦ Demo-Modus — so liefe die Anfrage'));
      expect(chunks.join(), res.text);
      expect(last!.output, greaterThan(0));
      expect(res.cost, greaterThan(0));
    });

    test('Abbruch wirft AiAbortException', () async {
      const cfg = ClaudeCfg();
      final cancel = AiCancelToken();
      final future = ClaudeClient().run(cfg, 'x', cancel: cancel);
      cancel.cancel();
      await expectLater(future, throwsA(isA<AiAbortException>()));
    });
  });

  group('countTokens (claude.js:105-116)', () {
    test('liefert input_tokens, scheitert LEISE mit null', () async {
      final ok = MockClient((request) async {
        expect(request.url.path, '/v1/messages/count_tokens');
        return http.Response(jsonEncode({'input_tokens': 321}), 200);
      });
      const cfg = ClaudeCfg(apiKey: 'sk');
      expect(await clientWith(ok).countTokens(cfg, 'p'), 321);

      final fail = MockClient((request) async => http.Response('nope', 500));
      expect(await clientWith(fail).countTokens(cfg, 'p'), isNull);

      // Ohne ready (kein Zugang, Demo aus) → null ohne Netz.
      expect(
        await ClaudeClient().countTokens(const ClaudeCfg(demo: false), 'p'),
        isNull,
      );
    });
  });
}
