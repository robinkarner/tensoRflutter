/// Studio-Screen — die Routen-Hülle des 3-Spalten-Arbeitsraums
/// (ersetzt die Welle-0-PlaceholderPage; Pendant zum Einstieg von
/// `renderStudio`, :40-49).
///
/// Routen-Parameter wie im Original ausgewertet: ungültige/fehlende
/// Abschnitts-ID → `studioLast` → erster Abschnitt mit Absätzen; ein
/// gültiger Modus wird persistiert (`studioMode`), der aktive Abschnitt
/// unter `studioLast`; `para` ist der Absatz-Anker (Karte öffnen +
/// jump-flash im Analyse-Modus).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../data/bundles/indexes.dart';
import '../../data/db/kv.dart';
import 'layout/studio_layout.dart';
import 'layout/studio_state.dart';

class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key, this.sec, this.modus, this.para});

  /// Abschnitt („3.2“), Modus (lesen|pruefen|editor), Absatz-Anker („p-3-2-4“).
  final String? sec;
  final String? modus;
  final String? para;

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  /// Zuletzt persistierter Abschnitt (verhindert wiederholte KV-Writes).
  String? _persistedSection;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final unitIndex = ref.watch(unitIndexProvider);
    final ordered = ref.watch(orderedUnitsProvider);
    final prefsAsync = ref.watch(studioPrefsCtlProvider);
    final kvAsync = ref.watch(studioKvProvider);

    // Boot/Prefs noch nicht bereit → ruhiger Ladehinweis (Splash-Pendant).
    if (ordered.isEmpty || prefsAsync.isLoading || kvAsync.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Text('Lade …',
              style: AppTextStyles.body.copyWith(color: t.muted)),
        ),
      );
    }
    final prefs = prefsAsync.value ?? StudioPrefs.defaults;
    final snapshot = kvAsync.value ?? const <String, Object?>{};

    // Abschnitt auflösen (:41-42): Route → studioLast → erste Unit.
    var sectionId = widget.sec;
    if (sectionId == null || unitIndex[sectionId] == null) {
      final last = snapshot[KvKeys.studioLast];
      sectionId = last is String && unitIndex[last] != null ? last : null;
    }
    sectionId ??= ordered.first;
    if (unitIndex[sectionId] == null) sectionId = ordered.first;

    // Modus: gültiger Routen-Modus > persistierter Modus (:43).
    final routeMode = widget.modus;
    final mode = (routeMode != null &&
            const {'lesen', 'pruefen', 'editor'}.contains(routeMode))
        ? routeMode
        : prefs.mode;

    // Seiteneffekte NACH dem Build: studioLast + studioMode persistieren.
    final resolvedSection = sectionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_persistedSection != resolvedSection) {
        _persistedSection = resolvedSection;
        ref
            .read(studioKvProvider.notifier)
            .put(KvKeys.studioLast, resolvedSection);
      }
      if (routeMode != null && routeMode != prefs.mode) {
        ref.read(studioPrefsCtlProvider.notifier).setMode(routeMode);
      }
    });

    return StudioWorkspace(
      sectionId: sectionId,
      mode: mode,
      focusPara: widget.para,
    );
  }
}
