/// ⌖ Referenzierungsmodus („Große Ansicht“) — Port von `openRefMode`/
/// `RefMode`/`refSetActive`/`refActiveInfo` (views_studio.js:1702-1810) samt
/// `.refmode` (app.css:615-711):
///
/// Vollbild-Overlay (z-90-Pendant: eigene, deckende Route mit fadeIn .14s):
/// links die Zitierelemente ALLER Quellen des Absatzes (`ref-src`-Karten mit
/// QUADRAT-Punkt, aktive Quelle mit Akzent-Ring), rechts PDF/Text/Register/
/// Datei der aktiven Quelle. Im PDF markieren → Zitat + Seite landen im
/// aktiven Beleg (Auto-Save). Esc schließt (Modale darüber fangen Esc
/// selbst — Navigator-Stack). „⇔ Panel“ blendet die Seitenspalte aus;
/// die Naht verstellt `--ref-w` (`uiRefW`, min 240). ≤900px stapelt
/// (Belege oben 34vh, PDF darunter).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/resizable.dart';
import '../../../data/db/kv.dart';
import '../../../data/models/models.dart';
import '../../../data/repos/file_store.dart';
import '../../pdf/pdf.dart';
import '../layout/studio_state.dart';
import 'ref_main.dart';
import 'ref_side.dart';

part 'ref_mode.g.dart';

/// Globaler Store-Key der Seitenspalten-Breite (nicht projekt-gescoped).
const String kUiRefWKey = 'uiRefW';

/// `uiRefW` — Breite der Zitierelemente-Spalte (px, null = Standard 360).
@Riverpod(keepAlive: true)
class RefWidth extends _$RefWidth {
  @override
  Future<int?> build() async {
    final v = await ref.watch(kvStoreProvider).getJson(kUiRefWKey);
    final n = v is num ? v.toInt() : int.tryParse('$v');
    return (n != null && n > 0) ? n : null;
  }

  void set(int? px) {
    state = AsyncData(px);
    final kv = ref.read(kvStoreProvider);
    px == null ? kv.remove(kUiRefWKey) : kv.setJson(kUiRefWKey, px);
  }
}

/// Slot-Einstieg (`StudioSlots.openRefMode`): Overlay nur öffnen, wenn der
/// Absatz Belege hat (:1708-1710).
void openStudioRefMode(
  BuildContext context, {
  required String sectionId,
  required String paraId,
  String? srcId,
  int? fn,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final domain = container.read(studioDomainProvider);
  final info = domain?.ctx.unitIndex[sectionId];
  Paragraph? p;
  for (final x in info?.unit.paragraphs ?? const <Paragraph>[]) {
    if (x.id == paraId) p = x;
  }
  if (domain == null || p == null) return;
  if (domain.paraBelege(sectionId, p).isEmpty) return;

  Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: true,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 140),
    reverseTransitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (context, animation, secondary) => RefModeScreen(
      sectionId: sectionId,
      paraId: paraId,
      focusSrcId: srcId,
      focusFn: fn,
    ),
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: animation, child: child),
  ));
}

class RefModeScreen extends ConsumerStatefulWidget {
  const RefModeScreen({
    super.key,
    required this.sectionId,
    required this.paraId,
    this.focusSrcId,
    this.focusFn,
  });

  final String sectionId;
  final String paraId;
  final String? focusSrcId;
  final int? focusFn;

  @override
  ConsumerState<RefModeScreen> createState() => RefModeScreenState();
}

class RefModeScreenState extends ConsumerState<RefModeScreen> {
  String? srcId;
  int? activeFn;

  /// Gemerkte Ansicht je Quelle (`RefMode.views`; `datei` ist TRANSIENT und
  /// wird nie gemerkt, :1940-1945).
  final Map<String, String> _views = {};
  bool _transientDatei = false;

  final PdfEngineController engine = PdfEngineController();
  bool _sideHidden = false;
  double? _liveRefW;

  /// Datei-/Text-Befund je Quelle (U.detectPdf / getSrcText — async).
  final Map<String, ({bool hasPdf, bool hasText})> _probe = {};

  final Map<int, TextEditingController> _zitatCtls = {};
  final Map<int, TextEditingController> _posCtls = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    for (final c in _zitatCtls.values) {
      c.dispose();
    }
    for (final c in _posCtls.values) {
      c.dispose();
    }
    super.dispose();
  }

  StudioDomain? get domain => ref.read(studioDomainProvider);

  Paragraph? get paragraph {
    final info = domain?.ctx.unitIndex[widget.sectionId];
    for (final p in info?.unit.paragraphs ?? const <Paragraph>[]) {
      if (p.id == widget.paraId) return p;
    }
    return null;
  }

  List<Beleg> get belege {
    final p = paragraph;
    final d = domain;
    if (p == null || d == null) return const [];
    return d.paraBelege(widget.sectionId, p);
  }

  /// Quellen-Reihenfolge des Absatzes (:1712-1715).
  List<String> get srcOrder {
    final d = domain;
    final order = <String>[];
    for (final b in belege) {
      final ids = b.quellen.isNotEmpty
          ? b.quellen
          : (d?.ctx.fnIndex[b.num]?.sources ?? const <String>[]);
      for (final id in ids) {
        if (!order.contains(id)) order.add(id);
      }
    }
    return order;
  }

  void _init() {
    final order = srcOrder;
    if (order.isEmpty) return;
    final focus = widget.focusSrcId;
    setState(() {
      srcId = (focus != null && order.contains(focus)) ? focus : order.first;
      activeFn = widget.focusFn ?? belege.first.num;
    });
    _probeSource(srcId!);
  }

  /// Datei-/Text-Befund einer Quelle laden (bestimmt die Auto-Ansicht).
  Future<void> _probeSource(String id) async {
    if (_probe.containsKey(id)) return;
    final files = await ref.read(fileStoreProvider.future);
    final kv = ref.read(kvStoreProvider);
    final has = await files.detectPdf(id, kv) ?? false;
    final text = await kv.getSrcText(id);
    if (!mounted) return;
    setState(() => _probe[id] = (hasPdf: has, hasText: text.isNotEmpty));
  }

  /// Befund verwerfen (nach Datei-Zuordnung/Text-Änderung neu laden).
  void invalidateProbe(String id) {
    _probe.remove(id);
    _probeSource(id);
  }

  /// PDF-Befund einer Quelle: `null` = Prüfung läuft noch („Lade Datei …“),
  /// sonst das `U.detectPdf`-Ergebnis.
  bool? hasPdfOf(String id) => _probe[id]?.hasPdf;

  /// `refShowSource` (:1925-1945): Quelle rechts anzeigen.
  void showSource(String id, {int? fn, String? forceView}) {
    setState(() {
      srcId = id;
      _transientDatei = forceView == 'datei';
      if (forceView != null && forceView != 'datei') _views[id] = forceView;
      if (fn != null) activeFn = fn;
    });
    _probeSource(id);
  }

  /// Effektive Ansicht der aktiven Quelle: transient `datei` > gemerkt >
  /// Auto (PDF > Text > Register(Recht) > PDF).
  String viewFor(String id, {required bool isLaw}) {
    if (_transientDatei) return 'datei';
    final stored = _views[id];
    if (stored != null) return stored;
    final probe = _probe[id];
    if (probe == null) return 'pdf';
    if (probe.hasPdf) return 'pdf';
    if (probe.hasText) return 'text';
    if (isLaw) return 'register';
    return 'pdf';
  }

  /// `refSetActive` (:1800-1810): aktiver Beleg + Sprung zur Beleg-Seite.
  void setActive(int fn) {
    setState(() => activeFn = fn);
    engine.refreshActive();
    final d = domain;
    final id = srcId;
    if (d == null || id == null) return;
    final marks = ref.read(levelsMarksForFnProvider)?.call(id, fn) ?? const [];
    final pg = marks.isNotEmpty ? marks.first.page : d.levels.info(fn).seite;
    final pgNum = pg is num ? pg.toInt() : int.tryParse('$pg');
    if (pgNum != null && pgNum > 0) engine.goto(pgNum);
  }

  /// `refActiveInfo` (:1812-1818) — Ziel der PDF-Markierung.
  ActiveBeleg? activeInfo() {
    final fn = activeFn;
    final d = domain;
    final id = srcId;
    if (fn == null || d == null || id == null) return null;
    final b = d.ctx.findBeleg(fn);
    final label = (b?.claim.isNotEmpty ?? false)
        ? b!.claim
        : (d.ctx.fnIndex[fn]?.text ?? '');
    return ActiveBeleg(
      fn: fn,
      farbe: d.levels.farbeFor(id, fn),
      label: label.length > 70 ? label.substring(0, 70) : label,
    );
  }

  TextEditingController zitatCtl(int fn) => _zitatCtls.putIfAbsent(fn, () {
        final inf = domain?.levels.info(fn);
        return TextEditingController(text: inf?.zitat ?? '');
      });

  /// Positions-Feld eines Items — der Positionstyp folgt der QUELLE des
  /// Items (Rechtsquellen/Online/Norm → Fundstelle, sonst PDF-Seite).
  TextEditingController posCtl(int fn, String itemSrcId) =>
      _posCtls.putIfAbsent(fn, () {
        final d = domain;
        final inf = d?.levels.info(fn);
        final posType = d?.levels.positionType(itemSrcId) ?? 'seite';
        return TextEditingController(
            text: posType == 'seite'
                ? (inf?.seite == null ? '' : '${inf?.seite}')
                : (inf?.fundstelle ?? ''));
      });

  /// `item._refSave()` (:1873-1890): Zitat + Position + Farbe speichern.
  void saveItem(int fn, String itemSrcId) {
    final d = domain;
    if (d == null) return;
    final posType = d.levels.positionType(itemSrcId);
    final pos = posCtl(fn, itemSrcId).text;
    final explicitFarbe = d.levels.entry(fn)?['farbe'];
    d.levels.save(fn, {
      'zitat': zitatCtl(fn).text.trim(),
      'seite': posType == 'seite' ? (int.tryParse(pos.trim()) ?? '') : '',
      'fundstelle': posType == 'fundstelle' ? pos.trim() : '',
      if (explicitFarbe is String && explicitFarbe.isNotEmpty)
        'farbe': explicitFarbe,
      'herkunft': 'manuell',
    });
  }

  /// PDF-Capture (:2009-2016): Zitat + Seite ins Item-Formular + Auto-Save.
  void onCapture(PdfCapture c) {
    final d = domain;
    final id = srcId;
    if (d == null || id == null) return;
    zitatCtl(c.fn).text = c.text;
    if (d.levels.positionType(id) == 'seite') {
      posCtl(c.fn, id).text = '${c.page}';
    }
    saveItem(c.fn, id);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final d = ref.watch(studioDomainProvider);
    final info = d?.ctx.unitIndex[widget.sectionId];
    final p = paragraph;
    if (d == null || info == null || p == null || srcId == null) {
      return Scaffold(backgroundColor: t.bg, body: const SizedBox.shrink());
    }

    final size = MediaQuery.sizeOf(context);
    final stacked = size.width <= BookClothTokens.bpNarrow;
    final storedW = ref.watch(refWidthProvider).value;
    final maxW = [
      640.0,
      [size.width * .6, size.width - 430].reduce((a, b) => a < b ? a : b),
    ].reduce((a, b) => a > b ? a : b);
    final refW =
        (_liveRefW ?? storedW?.toDouble() ?? 360).clamp(240.0, maxW);

    final side = RefSide(screen: this, paragraph: p);
    final main = RefMain(screen: this, srcId: srcId!);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, e) {
        // Esc schließt das Overlay (Modale darüber liegen im Navigator-Stack
        // ÜBER dieser Route und fangen Esc selbst, :1781-1786).
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- ref-head ---------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: t.surface,
                border: Border(bottom: BorderSide(color: t.borderStrong)),
                boxShadow: t.shadow1,
              ),
              child: Row(
                children: [
                  Text('⌖ REFERENZIERUNG',
                      style: AppTextStyles.eyebrow.copyWith(color: t.muted)),
                  const SizedBox(width: 12),
                  Text('Absatz ${widget.paraId}',
                      style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700, color: t.ink)),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      info.unit.isIntro ? info.chapter.title : info.unit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.small.copyWith(color: t.muted),
                    ),
                  ),
                  const Spacer(),
                  if (size.width > 760)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(
                          'Im PDF Text markieren → Zitat + Seite landen im aktiven Beleg',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.small.copyWith(color: t.muted),
                        ),
                      ),
                    ),
                  AppButton(
                    small: true,
                    tooltip:
                        'Zitierelemente ein-/ausblenden — mehr Breite fürs PDF',
                    onPressed: () =>
                        setState(() => _sideHidden = !_sideHidden),
                    child: const Text('⇔ Panel'),
                  ),
                  const SizedBox(width: 6),
                  AppButton(
                    small: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('✕ Schließen'),
                  ),
                ],
              ),
            ),
            // ---- ref-body ---------------------------------------------------
            Expanded(
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_sideHidden)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: 120,
                              maxHeight: size.height * .34,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: t.bgDeep,
                                border: Border(
                                    bottom:
                                        BorderSide(color: t.borderStrong)),
                              ),
                              child: side,
                            ),
                          ),
                        Expanded(child: main),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_sideHidden) ...[
                          SizedBox(
                            width: refW.toDouble(),
                            child: Container(
                              decoration: BoxDecoration(
                                color: t.bgDeep,
                                border: Border(
                                    right: BorderSide(color: t.border)),
                              ),
                              child: side,
                            ),
                          ),
                          ResizerHandle(
                            read: () => _liveRefW ?? refW.toDouble(),
                            apply: (px) => setState(() => _liveRefW = px),
                            persist: (px) {
                              ref.read(refWidthProvider.notifier).set(px);
                              setState(() => _liveRefW = null);
                            },
                            min: 240,
                            max: maxW,
                            onDone: engine.refresh,
                          ),
                        ],
                        Expanded(child: main),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
