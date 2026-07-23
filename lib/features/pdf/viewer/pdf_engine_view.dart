/// PdfEngineView — der PDF-Betrachter der App (Port von `PdfEngine.mount`,
/// pdfengine.js:842-1372) auf pdfrx-Basis:
///
///  * Endlos-Scroll ALLER Seiten untereinander (Seiten-Hintergrund IMMER
///    #fff, Schatten `0 2px 14px rgb(0 0 0/.18)`, Radius 3) mit Lazy-Render
///    in Sichtweite und Speicherfreigabe ferner Seiten (> 8 Abstand).
///  * Zoom fit (Breite − 26, min 0.35) bzw. ×/÷1.2 in 0.3–4; globale
///    Persistenz `pdfZoomPref` (Typ-Mix `"fit"`|Zahl) — kompakte
///    Einbettungen starten IMMER mit fit und schreiben nie.
///  * Text-Selektion (Modus ✥ Markieren) → Markierung in der Farbe des
///    aktiven Belegs + Auto-Kommentar-Pin bei x=0.94; `onCapture` übergibt
///    Zitat + Seite an den Beleg.
///  * 💬 Kommentar-Modus: Klick platziert einen Pin, Modus springt zurück.
///  * Volltextsuche (zirkulär ab Folgeseite) mit 2,6-s-Treffer-Flash.
///  * Tastatur: ←/→ Seite, +/− Zoom, 0 fit, Strg/⌘+F fokussiert die Suche.
///
/// `viewOnly` unterdrückt Marks UND die Modus-Gruppe (unbestätigte
/// Kandidaten-Vorschau); `compact` begrenzt die Scroll-Höhe auf
/// min(62 vh, 640 px) bzw. [maxScrollHeight].
library;

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/db/kv.dart';
import '../../../data/repos/file_store.dart';
import '../marks/mark_dialogs.dart';
import '../marks/mark_overlay.dart';
import '../marks/pdf_mark.dart';
import '../marks/pdf_marks_store.dart';
import '../marks/selection_rects.dart';
import '../search/pdf_text_search.dart';
import 'ocr_bar.dart';
import 'pdf_engine_toolbar.dart';
import 'viewer_geometry.dart';

/// onCapture-Payload (pdfengine.js:1227).
typedef PdfCapture = ({String text, int page, int fn, String markId});

/// Controller-Pendant zum mount()-Rückgabeobjekt: `goto`, `search`,
/// `refresh`/`refreshActive` (die Marks selbst sind reaktiv über den
/// Marks-Provider — refresh aktualisiert die Aktiv-Anzeige).
class PdfEngineController {
  _PdfEngineViewState? _state;

  void _attach(_PdfEngineViewState s) => _state = s;
  void _detach(_PdfEngineViewState s) {
    if (identical(_state, s)) _state = null;
  }

  bool get isAttached => _state != null;

  void goto(int page, {bool smooth = false}) => _state?._goto(page, smooth: smooth);

  /// Befüllt das Suchfeld und sucht (klickbare Suchbegriffe von außen —
  /// Beleg-Dock-Chips, pdfengine.js:1361).
  void search(String query) => _state?._externalSearch(query);

  void refresh() => _state?._refreshActive();

  void refreshActive() => _state?._refreshActive();
}

class PdfEngineView extends ConsumerStatefulWidget {
  const PdfEngineView({
    super.key,
    required this.srcId,
    this.page,
    this.getActive,
    this.onCapture,
    this.onMarksChange,
    this.compact = false,
    this.fit = false,
    this.data,
    this.viewOnly = false,
    this.controller,
    this.maxScrollHeight,
    this.unavailablePlaceholder,
  });

  final String srcId;

  /// Startseite (1-basiert), wird auf 1..N geklemmt.
  final int? page;

  /// Aktiver Beleg des Gastgebers — null heißt: Auswahl löst die Warnung
  /// „Kein Beleg aktiv …" aus, es entsteht KEINE Markierung.
  final ActiveBeleg? Function()? getActive;

  /// Zitat + Seite in den aktiven Beleg übernehmen.
  final void Function(PdfCapture capture)? onCapture;

  /// Nach Popover-Speichern/Löschen (Gastgeber aktualisiert z. B. Levels).
  final VoidCallback? onMarksChange;

  /// Kompakte Einbettung (Detailpanel): Scroll-Höhe begrenzt, Zoom immer
  /// fit, `pdfZoomPref` wird NIE geschrieben (pdfengine.js:852-856, 1291).
  final bool compact;

  /// fit-Option ohne Kompakt-Layout (ebenfalls ohne Zoom-Persistenz).
  final bool fit;

  /// Direkte Daten statt Store-Datei (Kandidaten-Vorschau).
  final Uint8List? data;

  /// Nur ansehen: keine Marks zeichnen/setzen, keine Modus-Gruppe.
  final bool viewOnly;

  final PdfEngineController? controller;

  /// Scroll-Höhen-Deckel im Kompakt-Modus (Default min(62 vh, 640));
  /// die Kandidaten-Vorschau setzt 340/420 (app.css:1284-1288).
  final double? maxScrollHeight;

  /// Anzeige, wenn keine Datei ladbar ist (mount() → null im Original).
  final Widget? unavailablePlaceholder;

  @override
  ConsumerState<PdfEngineView> createState() => _PdfEngineViewState();
}

class _PdfEngineViewState extends ConsumerState<PdfEngineView> {
  static Future<void>? _pdfrxInit;

  PdfDocument? _doc;
  bool _loading = true;
  bool _unavailable = false;

  List<Size> _pageDims = const [];
  Size _base = PeMetrics.a4;
  PageLayout? _pageLayout;

  bool _fitMode = true;
  double? _zoom;
  double _viewportW = 0;
  double _viewportH = 0;
  Timer? _refitTimer;

  int _page = 1;
  String _mode = 'select';
  bool _warnNoActive = false;

  final Map<int, ui.Image> _images = {};
  final Map<int, double> _imageZoom = {};
  final Set<int> _rendering = {};
  final Map<int, PdfPageText> _pageTexts = {};
  final Set<int> _textLoading = {};
  final Set<int> _scanPages = {};

  PdfTextSearch? _search;
  String _qInfo = '';
  String? _flashQuery;
  int? _flashTarget;
  int? _flashPage;
  List<MarkRect> _flashRects = const [];
  Timer? _flashTimer;

  // Live-Selektion (nur eine Seite — Ankerseiten-Beschnitt konstruktiv).
  int? _selPage;
  int? _selAnchor;
  int? _selFocus;

  final _vCtrl = ScrollController();
  final _hCtrl = ScrollController();
  late final TextEditingController _pageInput;
  final _searchCtrl = TextEditingController();
  final _rootFocus = FocusNode(debugLabel: 'pe-root');
  final _searchFocus = FocusNode(debugLabel: 'pe-q');
  bool _scrollScheduled = false;
  double _dpr = 1;

  @override
  void initState() {
    super.initState();
    _pageInput = TextEditingController(text: '1');
    widget.controller?._attach(this);
    _vCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void didUpdateWidget(PdfEngineView old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (old.srcId != widget.srcId || !identical(old.data, widget.data)) {
      _disposeDoc();
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dpr = MediaQuery.devicePixelRatioOf(context);
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _refitTimer?.cancel();
    _flashTimer?.cancel();
    _vCtrl.dispose();
    _hCtrl.dispose();
    _pageInput.dispose();
    _searchCtrl.dispose();
    _rootFocus.dispose();
    _searchFocus.dispose();
    _disposeDoc();
    super.dispose();
  }

  void _disposeDoc() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    _imageZoom.clear();
    _pageTexts.clear();
    _scanPages.clear();
    _search = null;
    _doc?.dispose();
    _doc = null;
  }

  // ---------------------------------------------------------------------
  // Laden
  // ---------------------------------------------------------------------

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _unavailable = false;
    });
    try {
      final data = widget.data ??
          await (await ref.read(fileStoreProvider.future)).getData(widget.srcId);
      if (data == null) {
        if (mounted) setState(() => _unavailable = true);
        return;
      }
      _pdfrxInit ??= pdfrxFlutterInitialize();
      await _pdfrxInit;
      final doc = await PdfDocument.openData(data, sourceName: 'pe:${widget.srcId}');
      if (!mounted) {
        doc.dispose();
        return;
      }

      // Zoom-Vorgabe: kompakt/fit IMMER fit; sonst globale pdfZoomPref.
      Object? pref = 'fit';
      if (!widget.compact && !widget.fit) {
        pref = await ref.read(kvStoreProvider).getJson(KvKeys.pdfZoomPref, 'fit');
      }
      final z = zoomFromPref(pref);

      setState(() {
        _doc = doc;
        _pageDims = [for (final p in doc.pages) Size(p.width, p.height)];
        _base = _pageDims.isNotEmpty ? _pageDims.first : PeMetrics.a4;
        _fitMode = z == null;
        _zoom = z;
        _page = (widget.page ?? 1).clamp(1, doc.pages.length);
        _pageInput.text = '$_page';
        _search = PdfTextSearch(
          pageCount: doc.pages.length,
          loadPageText: (n) async => (await _pageText(n))?.fullText ?? '',
        );
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_page > 1) _goto(_page);
        _renderVisible();
      });
    } catch (e) {
      debugPrint('PDF nicht dekodierbar: $e');
      if (mounted) {
        setState(() {
          _unavailable = true;
          _loading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------
  // Layout & Zoom
  // ---------------------------------------------------------------------

  double get _effectiveZoom =>
      _zoom ?? fitZoom(_viewportW > 0 ? _viewportW : _base.width + 26, _base.width);

  double? _layoutZoom;

  PageLayout _layoutNow() {
    final z = _effectiveZoom;
    if (_pageLayout == null || _layoutZoom != z) {
      _pageLayout = PageLayout.compute(_pageDims, z);
      _layoutZoom = z;
    }
    return _pageLayout!;
  }

  void _invalidateLayout() => _pageLayout = null;

  /// setZoom (pdfengine.js:1287-1295): Ankerseite merken, persistieren
  /// (nur nicht-kompakt), neu layouten, Anker anfahren, sichtbar rendern.
  void _setZoom(double? z) {
    final anchor = _page;
    setState(() {
      _fitMode = z == null;
      _zoom = z ?? fitZoom(_viewportW, _base.width);
      _invalidateLayout();
    });
    if (!widget.compact && !widget.fit) {
      // Typ-Mix beibehalten: "fit" oder Zahl.
      unawaited(ref
          .read(kvStoreProvider)
          .setJson(KvKeys.pdfZoomPref, zoomToPref(z)));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_vCtrl.hasClients) return;
      _jumpTo(_layoutNow().gotoTarget(anchor));
      _renderVisible();
    });
  }

  /// Container-Resize im Fit-Modus: nach 140 ms Debounce neu einpassen,
  /// aktuelle Seite bleibt Anker (pdfengine.js:1300-1312).
  void _onViewportChanged(double w, double h) {
    final first = _viewportW == 0;
    final changed = (w - _viewportW).abs() > .5;
    _viewportW = w;
    _viewportH = h;
    if (_zoom == null) {
      // Erster Layout-Durchlauf: fit sofort setzen (ohne Debounce).
      _zoom = fitZoom(w, _base.width);
      _invalidateLayout();
      WidgetsBinding.instance.addPostFrameCallback((_) => _renderVisible());
      return;
    }
    if (!_fitMode || !changed || first) return;
    _refitTimer?.cancel();
    _refitTimer = Timer(PeMetrics.resizeDebounce, () {
      if (!mounted || !_fitMode) return;
      final anchor = _page;
      setState(() {
        _zoom = fitZoom(_viewportW, _base.width);
        _invalidateLayout();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_vCtrl.hasClients) return;
        _jumpTo(_layoutNow().gotoTarget(anchor));
        _renderVisible();
      });
    });
  }

  void _jumpTo(double offset) {
    if (!_vCtrl.hasClients) return;
    _vCtrl.jumpTo(offset.clamp(0.0, _vCtrl.position.maxScrollExtent));
  }

  // ---------------------------------------------------------------------
  // Scroll / Seitenzahl-Follow / Speicherfreigabe
  // ---------------------------------------------------------------------

  void _onScroll() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    // rAF-Throttle-Pendant (pdfengine.js:1047-1050).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || _doc == null || !_vCtrl.hasClients) return;
      final layout = _layoutNow();
      final cur = layout.pageAt(_vCtrl.offset, _viewportH);
      if (cur != _page) {
        setState(() {
          _page = cur;
          _pageInput.text = '$cur';
        });
      }
      // Ferne Seiten freigeben (> 8 Abstand, js:1059-1063).
      final release = [
        for (final n in _images.keys)
          if (layout.shouldRelease(n, cur)) n,
      ];
      if (release.isNotEmpty) {
        setState(() {
          for (final n in release) {
            _images.remove(n)?.dispose();
            _imageZoom.remove(n);
          }
        });
      }
      _renderVisible();
    });
  }

  void _renderVisible() {
    if (_doc == null || !_vCtrl.hasClients) return;
    for (final n in _layoutNow().visiblePages(_vCtrl.offset, _viewportH)) {
      unawaited(_renderPage(n));
    }
  }

  // ---------------------------------------------------------------------
  // Seiten-Rendern
  // ---------------------------------------------------------------------

  Future<void> _renderPage(int n) async {
    final doc = _doc;
    if (doc == null || n < 1 || n > doc.pages.length) return;
    final z = _effectiveZoom;
    if (_imageZoom[n] == z || _rendering.contains(n)) return;
    _rendering.add(n);
    try {
      final page = doc.pages[n - 1];
      final img = await page.render(
        fullWidth: page.width * z * _dpr,
        fullHeight: page.height * z * _dpr,
        backgroundColor: 0xffffffff,
      );
      if (img == null) return;
      final image = await img.createImage();
      img.dispose();
      // Zoom-Wechsel während des Renderns → Ergebnis verwerfen (js:952).
      if (!mounted || _doc == null || _effectiveZoom != z) {
        image.dispose();
        return;
      }
      setState(() {
        _images[n]?.dispose();
        _images[n] = image;
        _imageZoom[n] = z;
      });
      unawaited(_ensurePageText(n));
      // Aufgeschobener Such-Flash (Ziel dieser Suche = diese Seite).
      if (_flashQuery != null && _flashTarget == n) {
        final q = _flashQuery!;
        _flashQuery = null;
        _flashTarget = null;
        unawaited(_flashIn(n, q));
      }
    } finally {
      _rendering.remove(n);
    }
  }

  Future<PdfPageText?> _pageText(int n) async {
    final doc = _doc;
    if (doc == null || n < 1 || n > doc.pages.length) return null;
    if (_pageTexts.containsKey(n)) return _pageTexts[n];
    if (_textLoading.contains(n)) {
      // Läuft bereits — kurz auf Ergebnis warten.
      while (_textLoading.contains(n)) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      return _pageTexts[n];
    }
    _textLoading.add(n);
    try {
      final text = await doc.pages[n - 1].loadStructuredText();
      _pageTexts[n] = text;
      return text;
    } catch (_) {
      return null;
    } finally {
      _textLoading.remove(n);
    }
  }

  Future<void> _ensurePageText(int n) async {
    final text = await _pageText(n);
    if (!mounted || text == null) return;
    // Kein/kaum Text (Scan)? → OCR-Hinweisleiste an der Seite (E3).
    if (!widget.viewOnly && text.fullText.trim().length < 20 && !_scanPages.contains(n)) {
      setState(() => _scanPages.add(n));
    }
  }

  // ---------------------------------------------------------------------
  // Navigation & Suche
  // ---------------------------------------------------------------------

  void _goto(int p, {bool smooth = false}) {
    final doc = _doc;
    if (doc == null || p < 1 || p > doc.pages.length) return;
    setState(() {
      _page = p;
      _pageInput.text = '$p';
    });
    final target = _layoutNow().gotoTarget(p);
    if (_vCtrl.hasClients) {
      final clamped = target.clamp(0.0, _vCtrl.position.maxScrollExtent);
      if (smooth) {
        _vCtrl.animateTo(clamped,
            duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
      } else {
        _vCtrl.jumpTo(clamped);
      }
    }
    unawaited(_renderPage(p));
  }

  void _externalSearch(String q) {
    _searchCtrl.text = q;
    unawaited(_searchNext(q));
  }

  Future<void> _searchNext(String query) async {
    final search = _search;
    if (search == null || search.isBusy) return;
    final q = query.trim().toLowerCase();
    if (q.length < 2) {
      setState(() => _qInfo = '');
      return;
    }
    setState(() => _qInfo = '… sucht');
    final result = await search.next(q, _page);
    if (!mounted) return;
    if (result == null) {
      setState(() => _qInfo = 'kein Treffer');
      return;
    }
    setState(() => _qInfo = result.info);
    final n = result.page;
    if (_imageZoom[n] == _effectiveZoom) {
      _goto(n);
      unawaited(_flashIn(n, q));
    } else {
      _flashQuery = q;
      _flashTarget = n;
      _goto(n);
    }
  }

  /// Treffer-Flash: alle Vorkommen 2,6 s hervorheben, erstes zentrieren
  /// (Pendant zu flashIn + scrollIntoView block:center, js:1020-1028).
  Future<void> _flashIn(int n, String q) async {
    final text = await _pageText(n);
    if (!mounted || text == null || _pageDims.length < n) return;
    final dims = _pageDims[n - 1];
    final lower = text.fullText.toLowerCase();
    final rects = <MarkRect>[];
    var idx = lower.indexOf(q);
    while (idx >= 0 && rects.length < 200) {
      final cap = captureRange(text, dims.width, dims.height, idx, idx + q.length - 1,
          zoom: _effectiveZoom);
      if (cap != null) rects.addAll(cap.rects);
      idx = lower.indexOf(q, idx + q.length);
    }
    if (rects.isEmpty) return;
    setState(() {
      _flashPage = n;
      _flashRects = rects;
    });
    // Ersten Treffer vertikal zentrieren.
    final layout = _layoutNow();
    final first = rects.first;
    final target = layout.topOf(n) +
        (first.y + first.h / 2) * dims.height * _effectiveZoom -
        _viewportH / 2;
    _jumpTo(target);
    _flashTimer?.cancel();
    _flashTimer = Timer(PeMetrics.flashDuration, () {
      if (!mounted) return;
      setState(() {
        _flashPage = null;
        _flashRects = const [];
      });
    });
  }

  // ---------------------------------------------------------------------
  // Selektion & Marks
  // ---------------------------------------------------------------------

  void _refreshActive() {
    if (!mounted) return;
    setState(() => _warnNoActive = false);
  }

  void _clearSelection() {
    if (_selPage == null) return;
    setState(() {
      _selPage = null;
      _selAnchor = null;
      _selFocus = null;
    });
  }

  List<MarkRect> _selectionRectsFor(int n) {
    if (_selPage != n || _selAnchor == null || _selFocus == null) return const [];
    final text = _pageTexts[n];
    if (text == null) return const [];
    final dims = _pageDims[n - 1];
    final cap = captureRange(text, dims.width, dims.height, _selAnchor!, _selFocus!,
        zoom: _effectiveZoom);
    return cap?.rects ?? const [];
  }

  void _onSelectStart(int n, Offset local, Size pagePx) {
    final text = _pageTexts[n];
    if (text == null) {
      unawaited(_ensurePageText(n));
      return;
    }
    final dims = _pageDims[n - 1];
    final idx = charIndexAt(
        text, dims.width, dims.height, local.dx / pagePx.width, local.dy / pagePx.height);
    if (idx == null) return;
    setState(() {
      _selPage = n;
      _selAnchor = idx;
      _selFocus = idx;
    });
  }

  void _onSelectUpdate(int n, Offset local, Size pagePx) {
    if (_selPage != n || _selAnchor == null) return;
    final text = _pageTexts[n];
    if (text == null) return;
    final dims = _pageDims[n - 1];
    final idx = charIndexAt(
        text, dims.width, dims.height, local.dx / pagePx.width, local.dy / pagePx.height);
    if (idx == null || idx == _selFocus) return;
    setState(() => _selFocus = idx);
  }

  /// mouseup-Pendant (pdfengine.js:1196-1229): Auswahl → Markierung +
  /// Auto-Pin + onCapture in den aktiven Beleg.
  void _onSelectEnd(int n) {
    if (_selPage != n || _selAnchor == null || _selFocus == null) return;
    final text = _pageTexts[n];
    if (text == null) {
      _clearSelection();
      return;
    }
    final dims = _pageDims[n - 1];
    final cap = captureRange(text, dims.width, dims.height, _selAnchor!, _selFocus!,
        zoom: _effectiveZoom);
    if (cap == null) {
      _clearSelection();
      return;
    }
    final active = widget.getActive?.call();
    if (active == null) {
      // Rote Warnung in der Aktiv-Anzeige, KEINE Markierung (js:1216).
      setState(() => _warnNoActive = true);
      return;
    }
    final mark = ref.read(pdfMarksProvider.notifier).addMark(
          widget.srcId,
          PdfMark.neu(
            fn: active.fn,
            page: n,
            rects: cap.rects,
            farbe: active.farbe,
            zitat: cap.text,
            comment: MarkComment(
              // Rechter Rand — parallel zur Markierung (js:1221-1223).
              x: 0.94,
              y: max(0, cap.rects.first.y - 0.005),
              text: '[${active.fn}] ${active.label ?? 'Beleg'}',
            ),
          ),
        );
    _clearSelection();
    setState(() => _warnNoActive = false);
    widget.onCapture?.call(
        (text: cap.text, page: n, fn: active.fn, markId: mark.id));
  }

  /// Klick auf eine Seite: Modus `select` → daten-basierter Mark-Hit-Test
  /// (js:1233-1249); Modus `comment` → Pin setzen (js:1268-1284).
  void _onTapUp(int n, Offset local, Size pagePx) {
    if (widget.viewOnly) return;
    final nx = local.dx / pagePx.width;
    final ny = local.dy / pagePx.height;

    if (_mode == 'comment') {
      final active = widget.getActive?.call();
      final mark = ref.read(pdfMarksProvider.notifier).addMark(
            widget.srcId,
            PdfMark.neu(
              fn: active?.fn,
              page: n,
              rects: const [],
              farbe: active?.farbe,
              comment: MarkComment(x: nx, y: ny, text: ''),
            ),
          );
      setState(() => _mode = 'select');
      showMarkPopover(context, ref,
          srcId: widget.srcId, mark: mark, onMarksChange: widget.onMarksChange);
      return;
    }

    // Offene Auswahl? Dann kein Hit-Test (Browser-Pendant: Klick löst die
    // Selektion) — nächster Klick trifft wieder Markierungen.
    if (_selPage != null) {
      _clearSelection();
      return;
    }
    final hits = [
      for (final m in ref.read(pdfMarksProvider.notifier).marks(widget.srcId))
        if (m.page == n && m.hitTest(nx, ny)) m,
    ];
    if (hits.length == 1) {
      showMarkPopover(context, ref,
          srcId: widget.srcId, mark: hits.first, onMarksChange: widget.onMarksChange);
    } else if (hits.length > 1) {
      showMarkChooser(context, ref,
          srcId: widget.srcId, hits: hits, onMarksChange: widget.onMarksChange);
    }
  }

  // ---------------------------------------------------------------------
  // Tastatur
  // ---------------------------------------------------------------------

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Nur wenn der Fokus nicht in einem Feld liegt (js:1341).
    if (!_rootFocus.hasPrimaryFocus) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _goto(_page - 1, smooth: true);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _goto(_page + 1, smooth: true);
    } else if (event.character == '+' || event.character == '=') {
      _setZoom(zoomIn(_zoom ?? _effectiveZoom));
    } else if (event.character == '-') {
      _setZoom(zoomOut(_zoom ?? _effectiveZoom));
    } else if (event.character == '0') {
      _setZoom(null);
    } else if (ctrl && key == LogicalKeyboardKey.keyF) {
      _searchFocus.requestFocus();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);

    if (_unavailable) {
      return widget.unavailablePlaceholder ??
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            color: t.surface2,
            child: Text('Keine Datei ladbar.',
                style: AppTextStyles.small.copyWith(color: t.muted)),
          );
    }
    if (_loading || _doc == null) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        color: t.surface2,
        child: Text('Lade PDF …',
            style: AppTextStyles.small.copyWith(color: t.muted)),
      );
    }

    final doc = _doc!;
    // Marks reaktiv beobachten — jede Store-Änderung zeichnet neu
    // (refreshMarks-Pendant); viewOnly unterdrückt sie komplett.
    final srcMarks = widget.viewOnly
        ? const <PdfMark>[]
        : (ref.watch(pdfMarksProvider).value?[widget.srcId] ?? const <PdfMark>[]);

    final toolbar = PdfEngineToolbar(
      page: _page,
      pageCount: doc.pages.length,
      pageInput: _pageInput,
      zoomPercent: (_effectiveZoom * 100).round(),
      searchController: _searchCtrl,
      searchFocus: _searchFocus,
      searchInfo: _qInfo,
      viewOnly: widget.viewOnly,
      mode: _mode,
      active: widget.getActive?.call(),
      warnNoActive: _warnNoActive,
      onPrev: () => _goto(_page - 1, smooth: true),
      onNext: () => _goto(_page + 1, smooth: true),
      onPageSubmitted: (n) => _goto(n),
      onZoomIn: () => _setZoom(zoomIn(_zoom ?? _effectiveZoom)),
      onZoomOut: () => _setZoom(zoomOut(_zoom ?? _effectiveZoom)),
      onFit: () => _setZoom(null),
      onSearch: (q) => unawaited(_searchNext(q)),
      onSearchCleared: () => setState(() => _qInfo = ''),
      onMode: (m) => setState(() => _mode = m),
    );

    final scrollArea = LayoutBuilder(builder: (context, constraints) {
      _onViewportChanged(constraints.maxWidth, constraints.maxHeight);
      final z = _effectiveZoom;
      final layout = _layoutNow();
      final maxPageW = _pageDims.fold<double>(0, (a, d) => max(a, d.width * z));
      final contentW = max(maxPageW + 2 * PeMetrics.padding, constraints.maxWidth);

      return Listener(
        // Klick gibt dem Viewer den Tastatur-Fokus, ohne Felder zu stören.
        onPointerDown: (_) {
          final focused = FocusManager.instance.primaryFocus;
          if (focused == null || focused.context == null ||
              focused.context!.widget is! EditableText) {
            _rootFocus.requestFocus();
          }
        },
        child: Scrollbar(
          controller: _vCtrl,
          child: SingleChildScrollView(
            controller: _vCtrl,
            child: SingleChildScrollView(
              controller: _hCtrl,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentW,
                height: layout.totalHeight,
                child: Stack(
                  children: [
                    for (var n = 1; n <= doc.pages.length; n++)
                      Positioned(
                        top: layout.topOf(n),
                        left: (contentW - _pageDims[n - 1].width * z) / 2,
                        width: _pageDims[n - 1].width * z,
                        height: _pageDims[n - 1].height * z,
                        child: _pageWidget(t, n, z, srcMarks),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });

    final body = widget.compact
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.maxScrollHeight ??
                  min(MediaQuery.sizeOf(context).height * .62, 640.0),
            ),
            child: scrollArea,
          )
        : Expanded(child: scrollArea);

    return Focus(
      focusNode: _rootFocus,
      onKeyEvent: _onKeyEvent,
      child: Container(
        color: t.surface2,
        child: Column(
          mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [toolbar, body],
        ),
      ),
    );
  }

  /// Eine Seite: weißes Blatt + Canvas-Bild + Overlays (Marks/Pins/Flash/
  /// Auswahl/OCR-Hinweis) + Gesten.
  Widget _pageWidget(BookClothTokens t, int n, double z, List<PdfMark> srcMarks) {
    final dims = _pageDims[n - 1];
    final pagePx = Size(dims.width * z, dims.height * z);
    final image = _images[n];
    final pageMarks = [for (final m in srcMarks) if (m.page == n) m];
    final interactive = !widget.viewOnly;

    Widget content = Container(
      decoration: BoxDecoration(
        // Seiten-Hintergrund IMMER weiß — auch im Dark-Theme.
        color: BookClothTokens.pdfPageBg,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(offset: Offset(0, 2), blurRadius: 14, color: Color(0x2E000000)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            RawImage(image: image, fit: BoxFit.fill),
          if (interactive || _flashPage == n)
            CustomPaint(
              painter: MarkHighlightPainter(
                marks: pageMarks,
                flashRects: _flashPage == n ? _flashRects : const [],
                selectionRects: interactive ? _selectionRectsFor(n) : const [],
                selectionColor: t.accent.withValues(alpha: .35),
                dark: t.brightness == Brightness.dark,
              ),
            ),
          if (interactive)
            for (final m in pageMarks)
              if (m.comment != null)
                MarkPin(
                  key: ValueKey('pin-${m.id}'),
                  mark: m,
                  pageSize: pagePx,
                  onMoved: (x, y) {
                    final c = m.comment;
                    ref.read(pdfMarksProvider.notifier).updateMark(
                        widget.srcId, m.id, {
                      'comment': MarkComment(x: x, y: y, text: c?.text ?? '').toJson(),
                    });
                  },
                  onTap: () => showMarkPopover(context, ref,
                      srcId: widget.srcId,
                      mark: m,
                      onMarksChange: widget.onMarksChange),
                ),
          if (interactive && _scanPages.contains(n))
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: PdfOcrHintBar(page: n),
            ),
        ],
      ),
    );

    if (interactive) {
      content = MouseRegion(
        cursor: _mode == 'select' ? SystemMouseCursors.text : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _onTapUp(n, d.localPosition, pagePx),
          onPanStart: _mode == 'select'
              ? (d) => _onSelectStart(n, d.localPosition, pagePx)
              : null,
          onPanUpdate: _mode == 'select'
              ? (d) => _onSelectUpdate(n, d.localPosition, pagePx)
              : null,
          onPanEnd: _mode == 'select' ? (_) => _onSelectEnd(n) : null,
          onPanCancel: _mode == 'select' ? _clearSelection : null,
          child: content,
        ),
      );
    }
    return content;
  }
}
