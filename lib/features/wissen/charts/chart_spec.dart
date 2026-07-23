/// Chart-Spezifikation der Notebook-Diagramme — der reine (testbare)
/// Datenteil von `Notebook.chart` (notebook.js:268-320).
///
/// Ein `chart`-Block trägt JSON:
/// `{ "type": "bar|barh|line|area|scatter|pie|donut", "title", "labels",
///   "series": [{name, values, color}], "stacked", "height", "x", "y" }`.
/// Serien ohne Namen heißen „Serie N“; ohne Labels zählen die Werte
/// der ersten Serie durch („1“, „2“, …). Der „nice“-Tick-Algorithmus und
/// das de-AT-Zahlenformat (`fmt`) sind exakt übernommen.
library;

import 'dart:math' as math;

import '../../../core/util/format.dart';

/// Eine Serie (Werte bleiben roh — scatter erlaubt `[x, y]`-Paare).
class NbChartSeries {
  final String name;
  final List<Object?> values;

  /// CSS-Farbstring (`#hex`) oder null → Palette nach Serien-Index.
  final String? color;

  const NbChartSeries({required this.name, required this.values, this.color});

  /// Werte als Zahlen (`Number(v) || 0`-Semantik).
  List<double> get numbers => [for (final v in values) numOf(v)];

  static double numOf(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}

class NbChartSpec {
  final String type;
  final String? title;
  final List<String> labels;
  final List<NbChartSeries> series;
  final bool stacked;
  final double? height;
  final String? x;
  final String? y;

  const NbChartSpec({
    this.type = 'bar',
    this.title,
    this.labels = const [],
    this.series = const [],
    this.stacked = false,
    this.height,
    this.x,
    this.y,
  });

  /// Tolerantes Lesen (`spec || {}`, Defaults wie notebook.js:269-273).
  factory NbChartSpec.fromJson(Map<String, dynamic> json) {
    final rawSeries = json['series'];
    final series = <NbChartSeries>[];
    if (rawSeries is List) {
      for (final (i, s) in rawSeries.indexed) {
        if (s is! Map) continue;
        series.add(NbChartSeries(
          name: (s['name'] is String && (s['name'] as String).isNotEmpty)
              ? s['name'] as String
              : 'Serie ${i + 1}',
          values: s['values'] is List ? List<Object?>.from(s['values']) : const [],
          color: s['color'] is String ? s['color'] as String : null,
        ));
      }
    }
    final rawLabels = json['labels'];
    final labels = rawLabels is List
        ? [for (final l in rawLabels) '$l']
        : [
            for (var i = 0; i < (series.firstOrNull?.values.length ?? 0); i++)
              '${i + 1}',
          ];
    final h = json['height'];
    return NbChartSpec(
      type: json['type'] is String ? json['type'] as String : 'bar',
      title: json['title'] is String ? json['title'] as String : null,
      labels: labels,
      series: series,
      stacked: json['stacked'] == true,
      height: h is num ? h.toDouble() : null,
      x: json['x'] is String ? json['x'] as String : null,
      y: json['y'] is String ? json['y'] as String : null,
    );
  }

  /// `stacked` zählt nur bei bar/area (notebook.js:311).
  bool get effectiveStacked => stacked && (type == 'bar' || type == 'area');
}

/// Zahlformat der Chart-Werte (notebook.js:275): Zahlen ≥1000 in de-AT
/// gruppiert, sonst auf 2 Nachkommastellen gerundet; Nicht-Zahlen als String.
String nbChartFmt(Object? v) => v is num ? fmtDeNum(v) : '$v';

/// „nice“-Ticks (notebook.js:314-320): Schrittweite aus der Spanne, dann
/// vMax/vMin auf Vielfache runden.
({double vMin, double vMax, double step}) niceTicks(
    double rawMin, double rawMax) {
  var vMax = math.max(rawMax, 1e-9);
  var vMin = math.min(0.0, rawMin);
  final span = vMax - vMin;
  final step = math.pow(10, (math.log(span / 4) / math.ln10).floorToDouble())
      .toDouble();
  final niceStep = span / step > 20
      ? step * 5
      : span / step > 8
          ? step * 2
          : step;
  vMax = (vMax / niceStep).ceilToDouble() * niceStep;
  vMin = (vMin / niceStep).floorToDouble() * niceStep;
  return (vMin: vMin, vMax: vMax, step: niceStep);
}

/// Wertebereich eines Achsen-Charts (inkl. Stack-Summen) — notebook.js:310-313.
({double vMin, double vMax, double step}) axisRange(NbChartSpec s) {
  final allVals = [for (final ser in s.series) ...ser.numbers];
  final stacked = s.effectiveStacked;
  var maxStack = 0.0;
  if (stacked) {
    for (var li = 0; li < s.labels.length; li++) {
      var sum = 0.0;
      for (final ser in s.series) {
        sum += li < ser.numbers.length ? ser.numbers[li] : 0;
      }
      maxStack = math.max(maxStack, sum);
    }
  }
  final rawMax = stacked
      ? maxStack
      : allVals.fold(0.0, math.max);
  final rawMin = allVals.fold(0.0, math.min);
  return niceTicks(rawMin, rawMax);
}
