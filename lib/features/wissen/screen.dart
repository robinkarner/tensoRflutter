/// Wissen-Screen (`#/analyse/:tab/:arg`) — dünne Routen-Hülle um die
/// Wissen-Welt (K-1): 8 Tabs in 3 Clustern samt eigener blauer Farbwelt
/// (Port von views_analyse.js + notebook.js + charts.js).
library;

import 'package:flutter/material.dart';

import 'tabs/wissen_page.dart';

class WissenScreen extends StatelessWidget {
  const WissenScreen({super.key, this.tab, this.arg});

  /// Tab-Key (buch, modus, instanzen, ueberblick, kapitel, fazit,
  /// kennzahlen, wuerdigung) + Tab-Argument (Kapitelnummer bzw. Instanz-id).
  final String? tab;
  final String? arg;

  @override
  Widget build(BuildContext context) => WissenPage(tab: tab, arg: arg);
}
