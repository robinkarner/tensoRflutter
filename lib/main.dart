/// Einstiegspunkt + Boot-Sequenz — Pendant zur Bootstrap-IIFE (app.js:6-50).
///
/// Reihenfolge wie im Original (die Reihenfolge ist hart, Dossier 01 §6):
///  1. Dateispeicher bereit (`PdfStore.ready`-Pendant; Fehler werden wie im
///     Original geschluckt — app.js:13) — verhindert das Boot-Race, bei dem
///     zugeordnete PDFs kurz als fehlend erschienen.
///  2. Projekt-Boot (F-C): aktive Arbeit laden, Builtins seeden, KV-Scope
///     setzen, Indizes füttern, Einmal-Import des Repo-Belegstands.
///  3. Erst DANN rendert der Router — bis dahin steht der Splash „Lade …“.
///
/// **Reboot statt reload (E8):** Das `location.reload()`-Muster des Originals
/// (Arbeitswechsel, Analysen-Import, …) ist hier die Invalidierung von
/// [ProjectBoot] (bzw. `ProjectBoot.reboot()`): [appBoot] hängt daran, die
/// App fällt sichtbar auf den Splash zurück und der komplette Daten-Graph
/// (Runtime → Indizes → Views) baut sich neu — inklusive der Caches, die das
/// Original stehen ließ (L2, bewusst gefixt).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_wiring.dart';
import 'core/router/router.dart';
import 'core/shell/theme_controller.dart';
import 'core/theme/theme.dart';
import 'core/theme/tokens.dart';
import 'core/theme/typography.dart';
import 'core/widgets/buttons.dart';
import 'data/bundles/bundle_loader.dart';
import 'data/repos/file_store.dart';
import 'data/repos/project_repository.dart';

part 'main.g.dart';

void main() {
  runApp(const ProviderScope(child: ThesisStudioApp()));
}

// ---------------------------------------------------------------------------
// Boot-Sequenz
// ---------------------------------------------------------------------------

/// Gesamter App-Boot: Dateispeicher → Projekt-Boot. Liefert das
/// [BootResult] (Runtime, Name, Warnungen) für Titel/Topbar.
@Riverpod(keepAlive: true)
Future<BootResult> appBoot(Ref ref) async {
  // Schritt 0: Paket-Verdrahtung (Slots + Marks-Brücke) — VOR dem ersten
  // Render jeder Ansicht, lebt/erneuert sich mit jedem (Re-)Boot.
  installAppWiring(ref);
  // Schritt 1: PdfStore.ready — Fehler nicht fatal (app.js:13: `catch {}`).
  try {
    await ref.watch(fileStoreProvider.future);
  } catch (_) {
    // Ohne Dateispeicher läuft die App weiter; PDF-Funktionen melden sich
    // dann selbst als nicht verfügbar.
  }
  // Schritt 2+3: Projekt laden, Indizes bauen, Einmal-Import.
  return ref.watch(projectBootProvider.future);
}

// ---------------------------------------------------------------------------
// App-Widget
// ---------------------------------------------------------------------------

class ThesisStudioApp extends ConsumerWidget {
  const ThesisStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = (ref.watch(themeControllerProvider).value ??
            ThemeSetting.auto)
        .themeMode;
    final boot = ref.watch(appBootProvider);

    // Fenstertitel „Thesis Studio — {Titel(60)}“ (app.js:50).
    final metaTitle = boot.value?.runtime.thesis.meta.title ?? '';
    final activeName = boot.value?.activeName ?? '';
    final workTitle = (metaTitle.isNotEmpty && metaTitle != 'Unbenannte Arbeit')
        ? metaTitle
        : activeName;
    final title =
        'Thesis Studio — ${workTitle.length > 60 ? workTitle.substring(0, 60) : workTitle}';

    // Vor Boot-Ende (und während eines Reboots) KEIN Router — der Splash
    // ist das Pendant zu `<div class="loading">Lade …</div>`.
    return switch (boot) {
      AsyncData() => MaterialApp.router(
          title: title,
          debugShowCheckedModeBanner: false,
          theme: appThemeLight,
          darkTheme: appThemeDark,
          themeMode: themeMode,
          routerConfig: ref.watch(appRouterProvider),
        ),
      AsyncError(:final error) => MaterialApp(
          title: 'Thesis Studio',
          debugShowCheckedModeBanner: false,
          theme: appThemeLight,
          darkTheme: appThemeDark,
          themeMode: themeMode,
          home: _BootError(error: error),
        ),
      _ => MaterialApp(
          title: 'Thesis Studio',
          debugShowCheckedModeBanner: false,
          theme: appThemeLight,
          darkTheme: appThemeDark,
          themeMode: themeMode,
          home: const _BootSplash(),
        ),
    };
  }
}

/// `.loading` (theme.css:574): zentrierter Muted-Text mit 60px Luft.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Text(
            'Lade …',
            style: AppTextStyles.body.copyWith(color: t.muted),
          ),
        ),
      ),
    );
  }
}

/// Boot-Fehler: Das Original loggt nur in die Konsole und läuft „irgendwie“
/// weiter (app.js:12) — mit Assets/DB als hartem Fundament ist hier ein
/// erklärender Bildschirm mit Neustart-Knopf die ehrlichere Entsprechung.
class _BootError extends ConsumerWidget {
  const _BootError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = BookClothTokens.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Projekt-Boot fehlgeschlagen',
                    style: AppTextStyles.h3.copyWith(color: t.ink)),
                const SizedBox(height: 8),
                Text('$error',
                    style: AppTextStyles.small.copyWith(color: t.ink2)),
                const SizedBox(height: 14),
                AppButton(
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    // Die ganze Boot-Kette frisch aufsetzen — auch die
                    // gecachten Fehlzustände von Bundle-Load und Projekt-Boot.
                    ref.invalidate(thesisBundleProvider);
                    ref.invalidate(projectBootProvider);
                  },
                  child: const Text('Neu versuchen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
