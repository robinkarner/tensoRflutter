/// Volltextsuche des Viewers — Port von `pageText`/`searchNext`
/// (pdfengine.js:1068-1108): Seitentexte werden lazy eingelesen und
/// lowercased gecacht; gesucht wird ab der NÄCHSTEN Seite, einmal ringsum
/// (zirkulär). Die Trefferanzeige zählt nur Seiten aus dem BISHERIGEN
/// Cache („S. {n} · {k}+ Seiten“ — bewusst ein „+", weil ungelesene Seiten
/// unbekannt sind).
///
/// Das Widget hängt hier nur den Text-Loader ein (pdfrx `loadText`);
/// OCR-Ersatztexte entfallen in V1 (E3).
library;

/// Ergebnis einer Suche.
class PdfSearchResult {
  /// Gefundene Seite (1-basiert).
  final int page;

  /// Trefferseiten im bisherigen Cache (≥ 1).
  final int knownHitPages;

  const PdfSearchResult({required this.page, required this.knownHitPages});

  /// Info-Text der Toolbar: `S. {n}` bzw. `S. {n} · {k}+ Seiten`.
  String get info => knownHitPages > 1 ? 'S. $page · $knownHitPages+ Seiten' : 'S. $page';
}

class PdfTextSearch {
  PdfTextSearch({required this.pageCount, required this.loadPageText});

  final int pageCount;

  /// Lazy-Loader: Seitentext (roh); Fehler dürfen werfen — die Seite wird
  /// dann als leer gecacht (wie das Original, js:1076).
  final Future<String> Function(int page) loadPageText;

  /// Cache: Seite → lowercased Text (Pendant zu `textCache`).
  final Map<int, String> cache = {};

  /// Parallel-Suchen verhindern (`searchBusy`, js:1080).
  bool _busy = false;
  bool get isBusy => _busy;

  Future<String> _text(int n) async {
    if (!cache.containsKey(n)) {
      try {
        cache[n] = (await loadPageText(n)).toLowerCase();
      } catch (_) {
        cache[n] = '';
      }
    }
    return cache[n]!;
  }

  /// Externe Cache-Aktualisierung (z. B. nach Rendern einer Seite).
  void prime(int page, String text) => cache[page] = text.toLowerCase();

  /// Nächste Trefferseite ab [currentPage] (exklusive), zirkulär.
  /// null = kein Treffer ODER Query < 2 Zeichen ODER bereits beschäftigt.
  Future<PdfSearchResult?> next(String query, int currentPage) async {
    if (_busy) return null;
    final q = query.trim().toLowerCase();
    if (q.length < 2) return null;
    _busy = true;
    try {
      for (var step = 1; step <= pageCount; step++) {
        final n = ((currentPage - 1 + step) % pageCount) + 1;
        if ((await _text(n)).contains(q)) {
          var hits = 0;
          for (var m = 1; m <= pageCount; m++) {
            if (cache.containsKey(m) && cache[m]!.contains(q)) hits++;
          }
          return PdfSearchResult(page: n, knownHitPages: hits);
        }
      }
      return null;
    } finally {
      _busy = false;
    }
  }
}
