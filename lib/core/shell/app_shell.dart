/// App-Shell — der Rahmen um alle Bereiche (Pendant zum `<body>`-Gerüst
/// der index.html): sticky Topbar (56px) oben, darunter der scrollende
/// Hauptbereich `main#app` mit der Fußzeile am Dokumentende.
///
/// Maße wie im Original (app.css:78-84): Main-Padding
/// `12px clamp(14px, 2vw, 26px) 80px`, Mindesthöhe des Mains
/// `100vh − Topbar − 60px` (die Fußzeile bleibt unter der Falz).
/// Vollhöhen-Ansichten (Studio-Spalten, Welle 1) leben INNERHALB dieses
/// Scrollbereichs — wie im Original, wo die Spalten sticky/viewport-hoch
/// im normal scrollenden Dokument stehen.
///
/// Außerdem hängt hier der globale Strg/⌘+K-Griff für die Command-Palette
/// (app.js:146-148) — fokus-unabhängig über [HardwareKeyboard].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cmdk.dart';
import 'footer.dart';
import 'topbar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  /// Aktuelle Router-Location (für Nav-Active + Popover-Schließen).
  final String location;

  /// Der Screen des aktiven Bereichs.
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Palette gerade offen? (verhindert Stapeln bei erneutem Strg+K —
  /// das Original ersetzt den cmdkRoot-Inhalt, wir öffnen gar nicht erst neu)
  bool _cmdkOpen = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final ctrlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (!ctrlOrCmd || event.logicalKey != LogicalKeyboardKey.keyK) return false;
    _openCmdk();
    return true; // Event verbrauchen (preventDefault, app.js:147)
  }

  Future<void> _openCmdk() async {
    if (_cmdkOpen || !mounted) return;
    _cmdkOpen = true;
    try {
      await openCmdk(context);
    } finally {
      _cmdkOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Topbar(location: widget.location),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = MediaQuery.sizeOf(context).width;
                // clamp(14px, 2vw, 26px)
                final hPad = (width * .02).clamp(14.0, 26.0);
                // min-height: 100vh − Topbar − 60px; der Expanded-Bereich ist
                // bereits Viewport minus Topbar → hier nur −60px.
                final minMain = constraints.maxHeight - 60;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: minMain > 0 ? minMain : 0,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 80),
                          child: widget.child,
                        ),
                      ),
                      const AppFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
