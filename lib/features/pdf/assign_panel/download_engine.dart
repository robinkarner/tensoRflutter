/// ⭳ Download-Engine — Port von `U.linkKind` (util.js:517-523),
/// `PdfEngine.dlLinkFor` (pdfengine.js:287-290) und `PdfEngine.tryDownload`
/// (pdfengine.js:297-319): EIN fetch-Versuch mit 20-s-Timeout und
/// `%PDF`-Magic-Check; Erfolg wird SOFORT als `<srcId>.pdf` zugeordnet,
/// jeder Ausgang landet persistent in `dlStatus`.
///
/// Fehlertexte wörtlich — einzige dokumentierte Abweichung (Dossier 05
/// §9.12): „CORS" entfällt außerhalb des Browsers, der Netzwerk-Fehlertext
/// lautet daher „blockiert (Netzwerk) — …".
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/db/kv.dart';
import '../../../data/repos/file_store.dart';
import '../../../data/repos/project_repository.dart';
import 'src_kv.dart';

part 'download_engine.g.dart';

/// Download-Timeout (pdfengine.js:302).
const Duration kDownloadTimeout = Duration(seconds: 20);

/// Worauf zeigt ein Link? `file` = direkte Datei (PDF), `page` = Webseite,
/// auf der man die Datei erst suchen muss; null bei leerem Link.
String? linkKind(String? url) {
  if (url == null || url.isEmpty) return null;
  if (RegExp(r'\.pdf($|[?#])', caseSensitive: false).hasMatch(url) ||
      RegExp(r'/pdf(/|$)', caseSensitive: false).hasMatch(url) ||
      RegExp(r'arxiv\.org/pdf', caseSensitive: false).hasMatch(url) ||
      RegExp('(download|fulltext|pdfdirect|epdf|viewcontent)', caseSensitive: false)
          .hasMatch(url)) {
    return 'file';
  }
  return 'page';
}

/// arXiv-Sonderfall: aus einer Abstract-/Landing-URL (`arxiv.org/abs/<id>`)
/// oder einer `/pdf/<id>`-URL die kanonische direkte PDF-URL ableiten.
/// Deckt Versions- (`…v2`) und Alt-IDs (`math/0309136`) ab. Sonst null.
///
/// arXiv hostet einen sehr großen Teil wissenschaftlicher Quellen; ohne diese
/// Ableitung würde „⭳ Alle laden“ bei Preprint-Quellen scheitern, weil die
/// Abstract-Seite HTML (kein `%PDF`) liefert.
String? arxivPdfUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final m = RegExp(r'arxiv\.org/(?:abs|pdf)/([^\s?#]+)', caseSensitive: false)
      .firstMatch(url);
  if (m == null) return null;
  final id = m.group(1)!.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  if (id.isEmpty) return null;
  return 'https://arxiv.org/pdf/$id.pdf';
}

/// Vermuteter Download-Link: `links.file` bzw. `official`, wenn dieser
/// direkt auf eine Datei zeigt — sonst null. arXiv-Landing-URLs werden auf
/// ihr PDF abgebildet (an beiden Stellen der Kaskade).
String? dlLinkFor(EffectiveSrcLinks links) {
  final file = links.file;
  if (file != null && file.isNotEmpty) return arxivPdfUrl(file) ?? file;
  final official = links.official;
  if (linkKind(official) == 'file') return official;
  return arxivPdfUrl(official);
}

/// `%PDF`-Magic-Bytes-Prüfung (pdfengine.js:308).
bool looksLikePdf(Uint8List data) =>
    data.length > 4 &&
    data[0] == 0x25 &&
    data[1] == 0x50 &&
    data[2] == 0x44 &&
    data[3] == 0x46;

class DownloadEngine {
  DownloadEngine({required this.files, required this.kv, http.Client? client})
      : client = client ?? http.Client();

  final FileStore files;
  final KvStore kv;
  final http.Client client;

  /// EIN Versuch über [dlLink]; Ergebnis wird IMMER in `dlStatus`
  /// persistiert. Erfolg ⇒ Datei liegt sofort unter `<srcId>` im FileStore
  /// (plus `pdfStatusCache[srcId] = true`).
  Future<DlStatus> tryDownload(String srcId, String? dlLink) async {
    Future<DlStatus> fail(String note) async {
      final r = DlStatus(ok: false, note: note);
      await kv.setDlStatus(srcId, r);
      return r;
    }

    if (dlLink == null || dlLink.isEmpty) {
      return fail('kein öffentlicher Datei-Link bekannt — Link ↗ von Hand laden '
          'oder über 🤖 Ergänzung nachtragen');
    }
    try {
      final resp = await client
          .get(Uri.parse(dlLink))
          .timeout(kDownloadTimeout, onTimeout: () => throw TimeoutException(null));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return fail('HTTP ${resp.statusCode} — Link ↗ von Hand laden, '
            'dann ⭱ Datei lokal wählen');
      }
      final data = resp.bodyBytes;
      if (!looksLikePdf(data)) {
        return fail('Antwort ist kein PDF (vermutlich HTML-Seite) — Link ↗ prüfen');
      }
      await files.addFiles([('$srcId.pdf', data)]);
      files.pdfStatusCache[srcId] = true;
      final r = const DlStatus(ok: true, note: 'geladen & zugeordnet');
      await kv.setDlStatus(srcId, r);
      return r;
    } on TimeoutException {
      return fail('Zeitüberschreitung (20 s)');
    } catch (_) {
      return fail('blockiert (Netzwerk) — Link ↗ von Hand laden, '
          'dann ⭱ Datei lokal wählen');
    }
  }
}

/// Engine als Provider — teilt FileStore + KV mit dem Rest der App.
@Riverpod(keepAlive: true)
Future<DownloadEngine> downloadEngine(Ref ref) async => DownloadEngine(
      files: await ref.watch(fileStoreProvider.future),
      kv: ref.watch(kvStoreProvider),
    );
