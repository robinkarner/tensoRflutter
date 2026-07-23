/// Hilfe-Screen (`#/hilfe/:topic?`) — dünne Routen-Hülle um die
/// K-2-Hilfe-Seite (Konstruktor-Signatur bleibt vertraglich erhalten,
/// CONTRACTS §11).
library;

import 'package:flutter/material.dart';

import 'hilfe_page.dart';

class HilfeScreen extends StatelessWidget {
  const HilfeScreen({super.key, this.topic});

  /// Routen-Parameter — das Original kennt keine Themen-Anker
  /// (`#/hilfe` rendert immer die ganze Seite); der Parameter bleibt für
  /// die Routen-Kompatibilität erhalten und wird wie dort ignoriert.
  final String? topic;

  @override
  Widget build(BuildContext context) => const HilfePage();
}
