/// Der App-Router — Pendant zum Hash-Router in app.js:210-248.
///
/// Aufbau:
///  * EINE [ShellRoute] trägt die App-Shell (Topbar + Main + Footer); die
///    sechs Live-Bereiche sind ihre Kinder.
///  * Alt-Routen (V1/V2) leben als reine Redirect-Routen daneben — sie
///    rendern nie, sondern übersetzen nur (app.js:236-239). Der Fallback
///    „ohne Abschnitt → zuletzt geöffneter bzw. erster Abschnitt“ liest wie
///    das Original den Store-Key `studioLast`.
///  * Unbekannte Routen fallen aufs Studio zurück — bewusst keine 404
///    (app.js:240: `else renderStudio(app, null, null)`).
///
/// Web nutzt die Hash-URL-Strategie (Flutter-Web-Default, kein
/// `usePathUrlStrategy`): URLs sehen aus wie `…/#/studio/3.2/lesen` — damit
/// bleiben gespeicherte Deep-Links aus der Original-Web-App gültig.
library;

import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/bundles/indexes.dart';
import '../../data/db/kv.dart';
import '../../features/doc/screen.dart';
import '../../features/hilfe/screen.dart';
import '../../features/projekt/screen.dart';
import '../../features/quellen/screen.dart';
import '../../features/studio/screen.dart';
import '../../features/wissen/screen.dart';
import '../shell/app_shell.dart';
import 'routes.dart';

part 'router.g.dart';

/// Der Router als langlebiger Provider. Er wird erst NACH dem Boot gebaut
/// (main.dart zeigt bis dahin den Splash), darf also synchron auf die
/// Index-Provider zugreifen.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  /// Ziel-Abschnitt für Alt-Routen ohne Abschnitt: `studioLast` oder der
  /// erste Abschnitt mit Inhalt (app.js:236-237: `U.storeGet('studioLast')
  /// || orderedUnits()[0]`).
  Future<String?> fallbackSection() async {
    final last = await ref.read(kvStoreProvider).getJson(KvKeys.studioLast);
    if (last is String && last.isNotEmpty) return last;
    final ordered = ref.read(orderedUnitsProvider);
    return ordered.isNotEmpty ? ordered.first : null;
  }

  /// `/lesen[/:id]` bzw. `/editor[/:id]` → `/studio/<sec>/<modus>`.
  Future<String> legacyStudio(GoRouterState state, String modus) async {
    final id = state.pathParameters[RouteParams.id];
    final sec = (id != null && id.isNotEmpty) ? id : await fallbackSection();
    return Routes.studioPath(sec: sec, modus: sec == null ? null : modus);
  }

  return GoRouter(
    initialLocation: Routes.studio,
    routes: [
      // ---------------------------------------------------------------
      // Shell: Topbar + Main + Footer um alle Live-Bereiche
      // ---------------------------------------------------------------
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.toString(), child: child),
        routes: [
          // --- Studio: /studio[/:sec[/:modus[/:para]]] ---
          GoRoute(
            path: Routes.studio,
            builder: (context, state) => const StudioScreen(),
            routes: [
              GoRoute(
                path: ':${RouteParams.sec}',
                builder: (context, state) => StudioScreen(
                  sec: state.pathParameters[RouteParams.sec],
                ),
                routes: [
                  GoRoute(
                    path: ':${RouteParams.modus}',
                    builder: (context, state) => StudioScreen(
                      sec: state.pathParameters[RouteParams.sec],
                      modus: state.pathParameters[RouteParams.modus],
                    ),
                    routes: [
                      // Absatz-Anker als viertes Segment (app.js:228).
                      GoRoute(
                        path: ':${RouteParams.para}',
                        builder: (context, state) => StudioScreen(
                          sec: state.pathParameters[RouteParams.sec],
                          modus: state.pathParameters[RouteParams.modus],
                          para: state.pathParameters[RouteParams.para],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // --- Dokument: /doc ---
          GoRoute(
            path: Routes.doc,
            builder: (context, state) => const DocScreen(),
          ),

          // --- Quellen: /quellen[/:id] ---
          GoRoute(
            path: Routes.quellen,
            builder: (context, state) => const QuellenScreen(),
            routes: [
              GoRoute(
                path: ':${RouteParams.id}',
                builder: (context, state) => QuellenScreen(
                  id: state.pathParameters[RouteParams.id],
                ),
              ),
            ],
          ),

          // --- Wissen: /analyse[/:tab[/:arg]] ---
          GoRoute(
            path: Routes.analyse,
            builder: (context, state) => const WissenScreen(),
            routes: [
              GoRoute(
                path: ':${RouteParams.tab}',
                builder: (context, state) => WissenScreen(
                  tab: state.pathParameters[RouteParams.tab],
                ),
                routes: [
                  GoRoute(
                    path: ':${RouteParams.arg}',
                    builder: (context, state) => WissenScreen(
                      tab: state.pathParameters[RouteParams.tab],
                      arg: state.pathParameters[RouteParams.arg],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // --- Projekt/Status: /projekt ---
          GoRoute(
            path: Routes.projekt,
            builder: (context, state) => const ProjektScreen(),
          ),

          // --- Hilfe: /hilfe[/:topic] ---
          GoRoute(
            path: Routes.hilfe,
            builder: (context, state) => const HilfeScreen(),
            routes: [
              GoRoute(
                path: ':${RouteParams.topic}',
                builder: (context, state) => HilfeScreen(
                  topic: state.pathParameters[RouteParams.topic],
                ),
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------------------------
      // Alt-Routen (V1/V2) — reine Weiterleitungen
      // ---------------------------------------------------------------
      GoRoute(path: '/', redirect: (context, state) => Routes.studio),
      GoRoute(path: Routes.legacyHome, redirect: (context, state) => Routes.studio),
      GoRoute(
        path: Routes.legacyLesen,
        redirect: (context, state) => legacyStudio(state, StudioModes.lesen),
        routes: [
          GoRoute(
            path: ':${RouteParams.id}',
            redirect: (context, state) => legacyStudio(state, StudioModes.lesen),
          ),
        ],
      ),
      GoRoute(
        path: Routes.legacyEditor,
        redirect: (context, state) => legacyStudio(state, StudioModes.editor),
        routes: [
          GoRoute(
            path: ':${RouteParams.id}',
            redirect: (context, state) => legacyStudio(state, StudioModes.editor),
          ),
        ],
      ),
      GoRoute(
        path: Routes.legacyExplorer,
        redirect: (context, state) => Routes.studio,
        routes: [
          GoRoute(
            path: ':${RouteParams.id}',
            redirect: (context, state) => Routes.studioPath(
              sec: state.pathParameters[RouteParams.id],
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.legacyZusammenfassung,
        redirect: (context, state) => Routes.analyse,
      ),
    ],

    // Unbekannte Route → Studio-Fallback statt Fehlerseite (app.js:240).
    onException: (context, state, router) => router.go(Routes.studio),
  );
}
