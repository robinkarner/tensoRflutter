/// Sammel-Export der Domänenschicht — reine Dart-Ports der JS-Module
/// levels/connections/mentions/stylecheck/texparse/editor (Logik), alle mit
/// Golden-Tests gegen die Original-Ausgaben (test/domain).
///
/// Kein Riverpod, keine Widgets: Die Klassen nehmen [DomainContext]
/// (Daten-Sicht) und [DomainStore] (KV-Persistenz) als Konstruktor-Argumente;
/// die Provider-Verdrahtung passiert in den Feature-Wellen.
library;

export '../core/util/sentences.dart';
export 'connections.dart';
export 'domain_context.dart';
export 'domain_store.dart';
export 'editor_logic.dart';
export 'js_compat.dart';
export 'levels.dart';
export 'mentions.dart';
export 'stylecheck.dart';
export 'texparse.dart';
