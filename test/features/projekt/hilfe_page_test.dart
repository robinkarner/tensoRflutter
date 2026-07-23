/// Widget-Smoke-Test der Hilfe-Seite (K-2): alle 5 Karten mit den
/// Original-Überschriften und Stichproben der wortwörtlichen Texte
/// (inkl. der dokumentierten Anpassungen E3/E5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thesor/core/theme/theme.dart';
import 'package:thesor/features/hilfe/hilfe_page.dart';
import 'package:thesor/features/hilfe/screen.dart';

void main() {
  /// Breiter Test-Viewport (Standard 800×600 ist schmäler als die
  /// 980px-Hilfe-Spalte plus Tabellen) — Reset über addTearDown.
  void wideView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host() => MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: HilfeScreen(topic: 'egal')),
        ),
      );

  testWidgets('Hilfe: Kopf, 5 Karten, Flow-Schritte', (tester) async {
    wideView(tester);
    await tester.pumpWidget(host());
    // Statische Seite — begrenzt pumpen (pumpAndSettle ist unter FakeAsync
    // bei async Unterbau riskant; hier defensiv einheitlich).
    await tester.pump();

    expect(find.text('Hilfe & Anleitung'), findsOneWidget);
    expect(find.byType(HilfePage), findsOneWidget);

    // Eyebrows rendern versal ('ß' → 'SS').
    expect(find.text('1 · So fließt alles zusammen'.toUpperCase()), findsOneWidget);
    expect(find.text('2 · KI-Teile nachträglich generieren & ersetzen'.toUpperCase()),
        findsOneWidget);
    expect(find.text('3 · Wo liegen meine Daten — und wie ersetze ich sie'.toUpperCase()),
        findsOneWidget);
    expect(find.text('4 · Im Web nutzen vs. lokal starten'.toUpperCase()),
        findsOneWidget);
    expect(find.text('5 · Bedienung & Barrierefreiheit'.toUpperCase()),
        findsOneWidget);

    // Flow: 5 Schritte + 4 Pfeile (das 5. „→“ ist die kbd-Taste in Karte 5).
    expect(find.text('LaTeX'), findsOneWidget);
    expect(find.text('GPT-Voranalyse'), findsOneWidget);
    expect(find.text('Belegstand'), findsOneWidget);
    expect(find.text('→'), findsNWidgets(5));
  });

  testWidgets('Hilfe: Tabellen-Inhalte + Bedienungs-Liste', (tester) async {
    wideView(tester);
    await tester.pumpWidget(host());
    // Statische Seite — begrenzt pumpen (pumpAndSettle ist unter FakeAsync
    // bei async Unterbau riskant; hier defensiv einheitlich).
    await tester.pump();

    // Tabelle 2 (Kopf versal per th-Stil).
    expect(find.text('BAUSTEIN'), findsOneWidget);
    expect(find.text('WO (PROMPT + IMPORT IN EINEM DIALOG)'), findsOneWidget);
    expect(find.textContaining('Komplette Voranalyse', findRichText: true),
        findsOneWidget);
    expect(
        find.textContaining('die gespeicherte Voranalyse der Arbeit',
            findRichText: true),
        findsOneWidget);

    // Tabelle 3 mit E7-Anpassung (lokale Datenbank statt localStorage).
    expect(find.textContaining('Lokale Datenbank der App', findRichText: true),
        findsOneWidget);

    // Bedienungs-Liste: Original-Punkte + dokumentierte Anpassungen.
    expect(
        find.textContaining('Der Arbeitsraum hat bis zu 4 parallele Bereiche',
            findRichText: true),
        findsOneWidget);
    expect(
        find.textContaining('Erwähnungs-Erkennung', findRichText: true),
        findsOneWidget);
    // E3: OCR-Anpassung.
    expect(
        find.textContaining('ist in dieser Version nicht enthalten',
            findRichText: true),
        findsWidgets);
    // E5: PDF → LaTeX zurückgestellt.
    expect(
        find.textContaining('📄 PDF → LaTeX (Beta):', findRichText: true),
        findsOneWidget);
  });
}
