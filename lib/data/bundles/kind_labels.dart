/// Quellen-Art-Labels und -Icons — Pendant zu `KIND_LABELS`/`KIND_ICONS`
/// aus util.js:926-932.
///
/// W5 (Master §8): Es existieren zwei Label-Varianten. Diese hier ist die
/// App-/Bundle-Variante (identisch mit `stats.kindLabels` der eingebauten
/// Arbeit) und gilt überall im UI sowie für Instanz-Arbeiten (buildRuntime
/// nutzt dieselbe Konstante). Die abweichende Fallback-Variante aus
/// build_data.js:65 ("Report/amtlicher Bericht", "EU-Rechtsakt", …) kommt
/// nur im Text der zur BUILD-Zeit erzeugten Fallback-Dossiers vor und wird
/// nicht nachgebaut — die Bundles enthalten diese Texte bereits fertig.
library;

/// Anzeige-Label je Quellen-Art (`kind`).
const Map<String, String> kindLabels = {
  'artikel': 'Peer-Review-Artikel',
  'konferenz': 'Konferenzbeitrag',
  'norm': 'Norm',
  'report': 'Report/Bericht',
  'online': 'Online-Quelle',
  'recht-eu': 'Rechtsquelle EU',
  'recht-at': 'Rechtsquelle AT',
};

/// Icon-Zeichen je Quellen-Art (exakte Unicode-Symbole des Originals).
const Map<String, String> kindIcons = {
  'artikel': '📄',
  'konferenz': '🎤',
  'norm': '📐',
  'report': '📊',
  'online': '🌐',
  'recht-eu': '🇪🇺',
  'recht-at': '🇦🇹',
};
