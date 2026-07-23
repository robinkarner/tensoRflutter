/// Quellen-Screen (`#/quellen/:id`) — dünne Routen-Hülle um die
/// Bibliothek (S-4): 4-Spur-Grid, Detailpanel, Import und Dateispeicher
/// (Port von `renderQuellen`, views_quellen.js:13-43).
library;

import 'package:flutter/material.dart';

import 'quellen.dart';

class QuellenScreen extends StatelessWidget {
  const QuellenScreen({super.key, this.id});

  /// Vorausgewählte Quellen-id (öffnet das Detailpanel).
  final String? id;

  @override
  Widget build(BuildContext context) {
    // ✎-Link-Dialog + Quellenseiten-Navigation der Quell-Karte andocken
    // (idempotent; siehe quellen.dart).
    registerQuellenHooks();
    return QuellenPage(openId: id);
  }
}
