/// PDF-Markierungen — Datenmodell des KV-Keys `pdfMarks` (Dossier 05 §3).
///
/// Die JSON-Form ist Vertrag (Migration bestehender Web-App-Marks!):
/// ```jsonc
/// { "<srcId>": [ { "id": "m…", "ts": 0, "fn": 42|null, "page": 15,
///     "farbe": "blau"|null, "zitat": "…",
///     "rects": [{"x":0..1,"y":0..1,"w":…,"h":…}],       // Ursprung oben links
///     "comment": {"x":0..1,"y":0..1,"text":"…"}|null } ] }
/// ```
/// Wie [LevelInfo] im Levels-Port hält [PdfMark] das ROHE JSON und bietet
/// typisierte Getter — so überleben unbekannte Felder jede Lese-Schreib-Runde
/// bitgenau (Belegstand-Export dumpt den KV-Wert 1:1).
library;

import '../../../data/models/json_utils.dart';

/// Toleranter double-Cast (json_utils kennt nur int/String — Koordinaten
/// sind aber Fließkommazahlen).
double _asDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

/// Ein normalisiertes Markierungs-Rechteck (0..1 relativ zur Seite,
/// Ursprung oben links, y wächst nach unten — NICHT PDF-Koordinaten).
class MarkRect {
  final double x, y, w, h;

  const MarkRect({required this.x, required this.y, required this.w, required this.h});

  factory MarkRect.fromJson(Map<String, Object?> json) => MarkRect(
        x: _asDouble(json['x']),
        y: _asDouble(json['y']),
        w: _asDouble(json['w']),
        h: _asDouble(json['h']),
      );

  Map<String, Object?> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  /// Punkt-in-Rechteck (Klick-Hit-Test, pdfengine.js:1245-1246).
  bool contains(double nx, double ny) =>
      nx >= x && nx <= x + w && ny >= y && ny <= y + h;
}

/// Der Kommentar-Pin einer Markierung (`comment`-Feld).
class MarkComment {
  final double x, y;
  final String text;

  const MarkComment({required this.x, required this.y, this.text = ''});

  factory MarkComment.fromJson(Map<String, Object?> json) => MarkComment(
        x: _asDouble(json['x']),
        y: _asDouble(json['y']),
        text: asString(json['text']),
      );

  Map<String, Object?> toJson() => {'x': x, 'y': y, 'text': text};
}

/// Eine Markierung. Hält das rohe JSON (Feld [json]) als Persistenz-Wahrheit.
class PdfMark {
  final Map<String, Object?> json;

  const PdfMark(this.json);

  /// Neu anzulegende Markierung (id/ts vergibt der Store beim addMark).
  factory PdfMark.neu({
    int? fn,
    required int page,
    List<MarkRect> rects = const [],
    String? farbe,
    String? zitat,
    MarkComment? comment,
  }) =>
      PdfMark({
        'fn': fn,
        'page': page,
        'rects': [for (final r in rects) r.toJson()],
        'farbe': farbe,
        'zitat': ?zitat,
        'comment': comment?.toJson(),
      });

  String get id => asString(json['id']);
  int get ts => asInt(json['ts']);

  /// Fußnoten-Nummer — null bei freiem Kommentar-Pin. Das Original vergleicht
  /// mit `Number(m.fn)`, daher tolerant gegen String-Werte.
  int? get fn => asIntOrNull(json['fn']);

  /// 1-basierte PDF-Seite.
  int get page => asInt(json['page']);

  /// Farb-KEY der Beleg-Palette (nicht Hex!) — `Levels.farbHex`-Fallback
  /// `#e8c33f` übernimmt der Renderer.
  String? get farbe => asStringOrNull(json['farbe']);

  String get zitat => asString(json['zitat']);

  List<MarkRect> get rects => [
        for (final r in asList(json['rects']))
          if (r is Map) MarkRect.fromJson(r.map((k, v) => MapEntry(k.toString(), v))),
      ];

  MarkComment? get comment {
    final c = json['comment'];
    if (c is! Map) return null;
    return MarkComment.fromJson(c.map((k, v) => MapEntry(k.toString(), v)));
  }

  /// Patch wie `Object.assign` (updateMark): flaches Mischen aufs rohe JSON.
  PdfMark patched(Map<String, Object?> patch) => PdfMark({...json, ...patch});

  /// Trifft ein normalisierter Punkt eine der Markierungsflächen?
  bool hitTest(double nx, double ny) => rects.any((r) => r.contains(nx, ny));
}
