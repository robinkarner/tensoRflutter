/// Quell-Metadaten im KV — Ports der util.js-Helfer, die die Quell-Karte
/// braucht (alle projekt-gescoped):
///  * `srcDoc`   — Dokument-Typ statt „keine Datei": {kind:'link',url} |
///                 {kind:'image'} (util.js:561-567)
///  * `srcTexts` — hinterlegter Quellentext (util.js:590-595)
///  * `srcExtras`— Material-Liste je Quelle (util.js:574-586)
///  * `srcNotes` — eigene Notizen (util.js:550-555)
///  * `dlStatus` — letzter Download-Versuch {ok, note} (util.js:416-421)
///  * `fileSearch` — Recherche-Metadaten (venue/publisher/openAccess/problem)
///  * `assignDismissed` — „✗ passt nicht"-Liste (pdfengine.js:258-264)
library;

import '../../../data/db/kv.dart';
import '../../../data/models/json_utils.dart';

/// Dokument-Typ einer Quelle ohne PDF: Internetquelle oder Bild.
class SrcDocDef {
  /// 'link' | 'image'.
  final String kind;
  final String? url;

  const SrcDocDef({required this.kind, this.url});

  bool get isLink => kind == 'link';
  bool get isImage => kind == 'image';

  Map<String, Object?> toJson() => {'kind': kind, if (url != null) 'url': url};

  static SrcDocDef? fromJson(Object? v) {
    final m = asMapOrNull(v);
    if (m == null) return null;
    final kind = asStringOrNull(m['kind']);
    if (kind == null || kind.isEmpty) return null;
    return SrcDocDef(kind: kind, url: asStringOrNull(m['url']));
  }
}

/// Material-Eintrag: {kind:'pdf'|'image'|'link'|'tex', key?, url?, name?, text?}.
class SrcExtra {
  final String kind;
  final String? key;
  final String? url;
  final String? name;
  final String? text;

  const SrcExtra({required this.kind, this.key, this.url, this.name, this.text});

  bool get isPdf => kind == 'pdf';
  bool get isImage => kind == 'image';
  bool get isLink => kind == 'link';
  bool get isTex => kind == 'tex';

  /// Anzeige-Text der Material-Zeile: name || url || key (pdfengine.js:490).
  String get label => name ?? url ?? key ?? '';

  /// Zeilen-Icon (pdfengine.js:489).
  String get icon => isPdf ? '📄' : isImage ? '🖼' : isTex ? 'Σ' : '🌐';

  Map<String, Object?> toJson() => {
        'kind': kind,
        if (key != null) 'key': key,
        if (url != null) 'url': url,
        if (name != null) 'name': name,
        if (text != null) 'text': text,
      };

  static SrcExtra? fromJson(Object? v) {
    final m = asMapOrNull(v);
    if (m == null) return null;
    return SrcExtra(
      kind: asString(m['kind']),
      key: asStringOrNull(m['key']),
      url: asStringOrNull(m['url']),
      name: asStringOrNull(m['name']),
      text: asStringOrNull(m['text']),
    );
  }
}

/// Download-Status {ok, note}.
class DlStatus {
  final bool ok;
  final String note;

  const DlStatus({required this.ok, required this.note});

  Map<String, Object?> toJson() => {'ok': ok, 'note': note};

  static DlStatus? fromJson(Object? v) {
    final m = asMapOrNull(v);
    if (m == null) return null;
    return DlStatus(ok: asBool(m['ok']), note: asString(m['note']));
  }
}

/// Recherche-Metadaten einer Quelle (`fileSearch[srcId]`).
class FileSearchInfo {
  final String? venue;
  final String? publisher;

  /// true = Open Access · false = Paywall · null = unbekannt.
  final bool? openAccess;
  final String? problem;

  const FileSearchInfo({this.venue, this.publisher, this.openAccess, this.problem});

  static FileSearchInfo? fromJson(Object? v) {
    final m = asMapOrNull(v);
    if (m == null) return null;
    return FileSearchInfo(
      venue: asStringOrNull(m['venue']),
      publisher: asStringOrNull(m['publisher']),
      openAccess: m['openAccess'] is bool ? m['openAccess'] as bool : null,
      problem: asStringOrNull(m['problem']),
    );
  }
}

/// Typisierter Zugriff auf die Quell-Metadaten-Keys. Die Lösch-Semantik der
/// util.js-Setter bleibt erhalten (leer/null ⇒ Eintrag fliegt aus der Map).
extension SrcKv on KvStore {
  // --- srcDoc ---

  Future<SrcDocDef?> getSrcDoc(String srcId) async =>
      SrcDocDef.fromJson((await getMap(KvKeys.srcDoc))[srcId]);

  Future<void> setSrcDoc(String srcId, SrcDocDef? doc) async {
    final all = Map<String, dynamic>.from(await getMap(KvKeys.srcDoc));
    if (doc != null) {
      all[srcId] = doc.toJson();
    } else {
      all.remove(srcId);
    }
    await setJson(KvKeys.srcDoc, all);
  }

  Future<void> clearSrcDoc(String srcId) => setSrcDoc(srcId, null);

  // --- srcTexts ---

  Future<String> getSrcText(String srcId) async =>
      asString((await getMap(KvKeys.srcTexts))[srcId]);

  Future<void> setSrcText(String srcId, String text) async {
    final all = Map<String, dynamic>.from(await getMap(KvKeys.srcTexts));
    if (text.trim().isNotEmpty) {
      all[srcId] = text;
    } else {
      all.remove(srcId);
    }
    await setJson(KvKeys.srcTexts, all);
  }

  // --- srcExtras ---

  Future<List<SrcExtra>> getSrcExtras(String srcId) async => [
        for (final v in asList((await getMap(KvKeys.srcExtras))[srcId]))
          if (SrcExtra.fromJson(v) case final SrcExtra x) x,
      ];

  Future<void> setSrcExtras(String srcId, List<SrcExtra> list) async {
    final all = Map<String, dynamic>.from(await getMap(KvKeys.srcExtras));
    if (list.isNotEmpty) {
      all[srcId] = [for (final x in list) x.toJson()];
    } else {
      all.remove(srcId);
    }
    await setJson(KvKeys.srcExtras, all);
  }

  Future<void> addSrcExtra(String srcId, SrcExtra item) async =>
      setSrcExtras(srcId, [...await getSrcExtras(srcId), item]);

  Future<void> removeSrcExtra(String srcId, int index) async {
    final list = await getSrcExtras(srcId);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await setSrcExtras(srcId, list);
  }

  // --- srcNotes ---

  Future<String> getSrcNote(String srcId) async =>
      asString((await getMap(KvKeys.srcNotes))[srcId]);

  Future<void> setSrcNote(String srcId, String text) async {
    final all = Map<String, dynamic>.from(await getMap(KvKeys.srcNotes));
    if (text.trim().isNotEmpty) {
      all[srcId] = text;
    } else {
      all.remove(srcId);
    }
    await setJson(KvKeys.srcNotes, all);
  }

  // --- dlStatus ---

  Future<DlStatus?> getDlStatus(String srcId) async =>
      DlStatus.fromJson((await getMap(KvKeys.dlStatus))[srcId]);

  Future<void> setDlStatus(String srcId, DlStatus? status) async {
    final all = Map<String, dynamic>.from(await getMap(KvKeys.dlStatus));
    if (status != null) {
      all[srcId] = status.toJson();
    } else {
      all.remove(srcId);
    }
    await setJson(KvKeys.dlStatus, all);
  }

  // --- fileSearch (nur lesen — geschrieben wird der Key von der KI-Welt) ---

  Future<FileSearchInfo?> getFileSearch(String srcId) async =>
      FileSearchInfo.fromJson((await getMap(KvKeys.fileSearch))[srcId]);

  // --- assignDismissed („✗ passt nicht") ---

  Future<List<String>> getDismissed(String srcId) async =>
      asStringList((await getMap(KvKeys.assignDismissed))[srcId]);

  Future<void> dismissCandidate(String srcId, String name) async {
    final all = Map<String, dynamic>.from(await getMap(KvKeys.assignDismissed));
    final list = asStringList(all[srcId]);
    if (!list.contains(name)) list.add(name);
    all[srcId] = list;
    await setJson(KvKeys.assignDismissed, all);
  }
}
