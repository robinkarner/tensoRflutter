/// Ablage-Kandidaten für eine Quelle — Port von `PdfEngine.findCandidates`
/// (pdfengine.js:266-282): Automatische Erkennung läuft NUR über den
/// Referenz-Hash (`ts-…` im Dateinamen) und die exakte Quellen-id aus dem
/// ZIP-Roundtrip — der Dateiname ist als Erkennungsmerkmal bewusst raus;
/// alles andere bleibt manuelle Wahl („Aus Dateiverzeichnis").
library;

/// Ein Kandidat aus der Ablage.
class AssignCandidate {
  final String name;

  /// 200 = Hash-Treffer · 150 = id-Datei (Sortier-Ranking).
  final int score;

  /// Begründungs-Chip: „automatisch erkannt" | „id-Datei".
  final String why;
  final bool sure;

  const AssignCandidate({
    required this.name,
    required this.score,
    required this.why,
    required this.sure,
  });
}

/// Kandidaten ermitteln, bestes Ranking zuerst. [inbox] = Ablage-Dateinamen,
/// [dismissed] = „✗ passt nicht"-Liste, [srcHash] = `ts-…`-Referenz-Hash.
List<AssignCandidate> findCandidates({
  required String srcId,
  required String srcHash,
  required List<String> inbox,
  required List<String> dismissed,
}) {
  final out = <AssignCandidate>[];
  for (final name in inbox) {
    if (dismissed.contains(name)) continue;
    final low = name.toLowerCase();
    if (low.contains(srcHash)) {
      out.add(AssignCandidate(name: name, score: 200, why: 'automatisch erkannt', sure: true));
      continue;
    }
    if (low.replaceAll(RegExp(r'\.pdf$'), '') == srcId.toLowerCase()) {
      out.add(AssignCandidate(name: name, score: 150, why: 'id-Datei', sure: true));
    }
  }
  out.sort((a, b) => b.score - a.score);
  return out;
}
