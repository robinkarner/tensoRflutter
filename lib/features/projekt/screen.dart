/// Projekt-/Status-Screen (`#/projekt`) — dünne Routen-Hülle um das
/// K-2-Dashboard (Konstruktor-Signatur bleibt vertraglich erhalten,
/// CONTRACTS §11).
library;

import 'package:flutter/material.dart';

import 'dashboard/projekt_page.dart';

class ProjektScreen extends StatelessWidget {
  const ProjektScreen({super.key});

  @override
  Widget build(BuildContext context) => const ProjektPage();
}
