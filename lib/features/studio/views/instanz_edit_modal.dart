/// ✎ Views verwalten — Port von `instanzEditModal` (views_studio.js:2360-2452):
/// wie eine App-Icon-Liste — je View eine Zeile (Farb-Punkt · Name · Auftrag ·
/// Σ-Verknüpfung · Zähler · ↻ Prompt · 🗑 Löschen) + Verschieben (↑/↓) und
/// Farbwahl (Token-Swatches + freie Farbe, `.ie-sw`), darunter „➕ Neue View“
/// (id = slugifizierter Name, max. 40 Zeichen), unten „↺ Standard“ und
/// „Fertig“. Alles speichert sofort (`instDefs`); der Original-LaTeX bleibt
/// unangetastet.
///
/// ↻ öffnet in Welle 1 den ⧉-Kopieren-Pfad (Prompt der View — extern
/// ausführen); die Direkt-Generierung mit Claude hängt K-3 hier ein.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/db/kv.dart';
import '../layout/css_color.dart';
import '../layout/dock_state.dart';
import '../layout/studio_state.dart';
import 'instanz_prompt.dart';

void showInstanzEditModal(BuildContext context, WidgetRef ref) {
  showAppModal<void>(
    context,
    title: const Text('✎ Views verwalten'),
    body: const _VeBody(),
  );
}

/// K-3-Andockstelle (CONTRACTS §14): Direkt-Generierung einer View mit
/// Claude (`viewGenerate`-Pendant). Registriert von `wireAiHooks()` über
/// lib/app_wiring.dart — ohne Registrierung bleibt der ⧉-Kopieren-Pfad.
abstract final class InstanzGenerateHook {
  /// ↻ Recompile — liefert true, wenn die KI-Schicht übernommen hat.
  static bool Function(BuildContext context, DockDef def)? recompile;

  /// ➕ Erstellen & Generieren — nur bei Zugang/Demo (sonst no-op; die
  /// View bleibt leer, views_studio.js:2440-2443).
  static void Function(BuildContext context, DockDef def)? afterCreate;
}

/// Token-Swatches der Farbwahl (`.ie-colors`): View-Farben bleiben als
/// CSS-Strings persistiert (Original-Format).
const List<(String, String)> kViewColorTokens = [
  ('Petrol', 'var(--cat-norm)'),
  ('Frist', 'var(--cat-frist)'),
  ('Akteur', 'var(--cat-akteur)'),
  ('Technik', 'var(--cat-tech)'),
  ('These', 'var(--cat-these)'),
  ('Lücke', 'var(--cat-luecke)'),
  ('Zahl', 'var(--cat-zahl)'),
  ('Abkürzung', 'var(--cat-abk)'),
  ('Schlagwort', 'var(--cat-schlag)'),
  ('Grün', 'var(--good)'),
  ('Terracotta', 'var(--accent-ink)'),
  ('KI-Blau', 'var(--ki)'),
  ('Wissen', 'var(--wissen)'),
];

/// Arbeits-Kopie einer View-Definition (Inputs speichern sofort durch).
class _VeDef {
  String id;
  String label;
  String desc;
  String color;
  String srcTex;
  bool special;
  bool project;

  _VeDef.from(DockDef d)
      : id = d.id,
        label = d.label,
        desc = d.desc,
        color = d.color,
        srcTex = d.srcTex,
        special = d.special,
        project = d.project;

  Map<String, Object?> toStored() => {
        'id': id,
        'label': label.trim().isNotEmpty ? label.trim() : id,
        'desc': desc.trim(),
        'color': color,
        'srcTex': srcTex,
      };
}

class _VeBody extends ConsumerStatefulWidget {
  const _VeBody();

  @override
  ConsumerState<_VeBody> createState() => _VeBodyState();
}

class _VeBodyState extends ConsumerState<_VeBody> {
  late List<_VeDef> _defs;
  final Map<String, TextEditingController> _nameCtls = {};
  final Map<String, TextEditingController> _descCtls = {};
  final TextEditingController _newName = TextEditingController();
  final TextEditingController _newDesc = TextEditingController();
  String _newTex = '';

  @override
  void initState() {
    super.initState();
    _defs = [for (final d in ref.read(dockDefsProvider)) _VeDef.from(d)];
  }

  @override
  void dispose() {
    for (final c in _nameCtls.values) {
      c.dispose();
    }
    for (final c in _descCtls.values) {
      c.dispose();
    }
    _newName.dispose();
    _newDesc.dispose();
    super.dispose();
  }

  /// `save(defs)` (:2389-2392): speichert instDefs sofort; zeigt die
  /// globale Auswahl auf eine gelöschte View, fällt sie auf ∅ zurück.
  void _save() {
    ref.read(studioKvProvider.notifier).put(
        StudioUiKeys.instDefs, [for (final d in _defs) d.toStored()]);
    final prefs = ref.read(studioPrefsCtlProvider).value ?? StudioPrefs.defaults;
    if (prefs.dock != null && !_defs.any((d) => d.id == prefs.dock)) {
      ref.read(studioPrefsCtlProvider.notifier).setDock(null);
    }
  }

  /// `wipeContent(id)` (:2393-2397): Inhalte der View entfernen.
  void _wipeContent(String id) {
    final kv = ref.read(studioKvProvider.notifier);
    final all = {...kv.readMap(KvKeys.paraDock)}..remove(id);
    kv.put(KvKeys.paraDock, all);
  }

  int _contentCount(String id) {
    final snapshot =
        ref.read(studioKvProvider).value ?? const <String, Object?>{};
    final all = snapshot[KvKeys.paraDock];
    if (all is Map && all[id] is Map) return (all[id] as Map).length;
    return 0;
  }

  /// Verschieben in der sichtbaren Liste — „◻ Ohne“ (clear) bleibt zuletzt.
  void _move(String id, int delta) {
    final visible = [for (final d in _defs) if (d.id != 'clear') d];
    final idx = visible.indexWhere((d) => d.id == id);
    final to = idx + delta;
    if (idx < 0 || to < 0 || to >= visible.length) return;
    final item = visible.removeAt(idx);
    visible.insert(to, item);
    final clear = _defs.where((d) => d.id == 'clear').toList();
    setState(() => _defs = [...visible, ...clear]);
    _save();
  }

  /// ➕ Erstellen (:2429-2443) — ohne KI-Zugang wird die View leer angelegt.
  void _add() {
    final name = _newName.text.trim();
    final desc = _newDesc.text.trim();
    if (name.isEmpty) return;
    final id = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9äöüß]+', caseSensitive: false), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final short = id.length > 40 ? id.substring(0, 40) : id;
    if (short.isEmpty || _defs.any((d) => d.id == short)) {
      _showInfoDialog('Name leer oder schon vergeben.');
      return;
    }
    final def = DockDef(id: short, label: name, desc: desc, srcTex: _newTex);
    final clear = _defs.where((d) => d.id == 'clear').toList();
    final rest = [for (final d in _defs) if (d.id != 'clear') d];
    setState(() {
      _defs = [...rest, _VeDef.from(def), ...clear];
      _newName.clear();
      _newDesc.clear();
      _newTex = '';
    });
    _save();
    // K-3: bei vorhandenem Zugang wird die neue View direkt generiert.
    InstanzGenerateHook.afterCreate?.call(context, def);
  }

  /// ↺ Standard (:2444-2450): eigene Views (samt Inhalten) entfernen,
  /// `instDefs = null`, Modal schließen.
  Future<void> _resetDefaults() async {
    final ok = await _confirmDialog(
        'Alle Views auf den Standard zurücksetzen? Eigene Views (samt Inhalten) werden entfernt.');
    if (!ok || !mounted) return;
    for (final d in _defs) {
      final isDefault = dockDefaults.any((x) => x.id == d.id);
      if (!d.special && !isDefault && !d.project) _wipeContent(d.id);
    }
    ref.read(studioKvProvider.notifier).put(StudioUiKeys.instDefs, null);
    closeAppModal();
  }

  Future<void> _delete(_VeDef d) async {
    final n = _contentCount(d.id);
    final ok = await _confirmDialog(
        'View „${d.label}" löschen? Ihre generierten Inhalte ($n Absätze) werden mit entfernt.');
    if (!ok || !mounted) return;
    _wipeContent(d.id);
    setState(() => _defs = [for (final x in _defs) if (x.id != d.id) x]);
    _save();
  }

  /// ↻: Direkt-Generierung mit Claude (K-3-Hook); ohne Registrierung der
  /// Welle-1-Pfad — Prompt der View zum ⧉-Kopieren.
  void _recompile(_VeDef d) {
    final hook = InstanzGenerateHook.recompile;
    if (hook != null &&
        hook(context,
            DockDef(id: d.id, label: d.label, desc: d.desc, srcTex: d.srcTex))) {
      return;
    }
    final domain = ref.read(studioDomainProvider);
    if (domain == null) return;
    final snapshot =
        ref.read(studioKvProvider).value ?? const <String, Object?>{};
    final prompt = instanzPromptFor(
      domain.ctx,
      [DockDef(id: d.id, label: d.label, desc: d.desc, srcTex: d.srcTex)],
      materials: texMaterialsFrom(snapshot[KvKeys.srcExtras]),
    );
    showDialog<void>(
      context: context,
      builder: (context) => _PromptDialog(label: d.label, prompt: prompt),
    );
  }

  Future<bool> _confirmDialog(String text) async {
    final t = BookClothTokens.of(context);
    final res = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BookClothTokens.radiusLg)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text,
                  style: AppTextStyles.small
                      .copyWith(fontSize: 14, height: 1.5, color: t.ink)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    small: true,
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 6),
                  AppButton(
                    small: true,
                    variant: AppButtonVariant.primary,
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return res ?? false;
  }

  void _showInfoDialog(String text) {
    _confirmDialog(text);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final domain = ref.watch(studioDomainProvider);
    final snapshot =
        ref.watch(studioKvProvider).value ?? const <String, Object?>{};
    final texSrcs = [
      ...{
        for (final m in texMaterialsFrom(snapshot[KvKeys.srcExtras])) m.srcId,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(
                text: 'Views sind Ebenen ÜBER dem Text — je Absatz generiert '
                    '(Markdown), jederzeit '),
            const TextSpan(
                text: 'neu kompilierbar',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(
                text: ' (↻ ersetzt die Inhalte der View) und '),
            const TextSpan(
                text: 'löschbar',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' (View + Inhalte). '),
            const TextSpan(
                text: 'Σ', style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(
                text: ' verknüpft eine View übergeordnet mit dem '
                    'LaTeX-Material einer Quelle (Material-Typ „Σ LaTeX" an der '
                    'Quelle) — die Generierung nutzt es als Textbasis. Der '
                    'Original-LaTeX bleibt immer unangetastet.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted, height: 1.55),
        ),
        const SizedBox(height: 12),
        // ---- ve-list --------------------------------------------------------
        for (final (i, d) in [
          for (final d in _defs)
            if (d.id != 'clear') d,
        ].indexed)
          _veRow(t, domain, texSrcs, d, i),
        const SizedBox(height: 12),
        // ---- ➕ Neue View ----------------------------------------------------
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: t.surface2,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(BookClothTokens.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('➕ NEUE VIEW — DIE KI FÜLLT SIE AUS DEM LATEX',
                  style: AppTextStyles.eyebrow.copyWith(color: t.muted)),
              const SizedBox(height: 7),
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: _input(t, _newName,
                        hint: 'Name (z. B. „Kritik“, „Beispiele“)'),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _input(t, _newDesc,
                        hint:
                            'Auftrag je Absatz (z. B. „Nenne je Absatz ein konkretes Praxisbeispiel, 1–2 Sätze“)'),
                  ),
                  if (texSrcs.isNotEmpty) ...[
                    const SizedBox(width: 7),
                    _texSelect(t, domain, texSrcs, _newTex,
                        (v) => setState(() => _newTex = v)),
                  ],
                  const SizedBox(width: 7),
                  AppButton(
                    small: true,
                    variant: AppButtonVariant.primary,
                    onPressed: _add,
                    child: const Text('➕ Erstellen & Generieren'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Erlaubte Syntax: einfacher Markdown (fett/kursiv/Listen), kein '
                'LaTeX. Ohne Zugang wird die View leer angelegt — Inhalte dann '
                'über den GPT-Hub oben (🎛 Instanzen: ⧉ kopieren / ⭱ einfügen).',
                style: AppTextStyles.small.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Spacer(),
            AppButton(
              small: true,
              tooltip:
                  'Standard-Views wiederherstellen (eigene Views und Umbenennungen zurücksetzen)',
              onPressed: _resetDefaults,
              child: const Text('↺ Standard'),
            ),
            const SizedBox(width: 6),
            AppButton(
              small: true,
              variant: AppButtonVariant.primary,
              onPressed: closeAppModal,
              child: const Text('Fertig'),
            ),
          ],
        ),
      ],
    );
  }

  /// Eine `.ve-row`: ↑↓ · Farb-Punkt · Name · Auftrag/Σ · Zähler · ↻ · 🗑.
  Widget _veRow(BookClothTokens t, StudioDomain? domain, List<String> texSrcs,
      _VeDef d, int index) {
    final visible = [for (final x in _defs) if (x.id != 'clear') x];
    final color = resolveCssColor(t, d.color) ?? t.borderStrong;
    final n = _contentCount(d.id);
    final nameCtl = _nameCtls.putIfAbsent(
        d.id, () => TextEditingController(text: d.label));
    final descCtl = _descCtls.putIfAbsent(
        d.id, () => TextEditingController(text: d.desc));

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: t.surface2,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ↑↓-Verschieben (`.ie-move`).
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _moveBtn(t, '▲', index > 0, () => _move(d.id, -1)),
              const SizedBox(height: 2),
              _moveBtn(t, '▼', index < visible.length - 1,
                  () => _move(d.id, 1)),
            ],
          ),
          const SizedBox(width: 8),
          _ColorSwatchButton(
            color: color,
            css: d.color,
            special: d.special,
            onPick: (css) {
              setState(() => d.color = css);
              _save();
            },
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: d.special
                ? Text(d.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small
                        .copyWith(fontWeight: FontWeight.w600, color: t.ink2))
                : _input(t, nameCtl,
                    tooltip: 'Name der View — speichert sofort',
                    onChanged: (v) {
                      d.label = v;
                      _save();
                    }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: d.special
                ? Text(
                    d.id == 'schnell'
                        ? 'Schnelllese-Anstrich — feste Funktion'
                        : d.id == 'srcview'
                            ? 'streicht Sätze der aktiven Quelle an — feste Funktion'
                            : 'Verbindungs-Graph — feste Funktion',
                    style: AppTextStyles.small.copyWith(color: t.muted),
                  )
                : _input(t, descCtl,
                    hint: 'Auftrag je Absatz (GPT) — speichert sofort',
                    tooltip: 'Der Auftrag, den die KI je Absatz ausführt',
                    onChanged: (v) {
                      d.desc = v;
                      _save();
                    }),
          ),
          if (!d.special && (texSrcs.isNotEmpty || d.srcTex.isNotEmpty)) ...[
            const SizedBox(width: 8),
            _texSelect(t, domain, texSrcs, d.srcTex, (v) {
              setState(() => d.srcTex = v);
              _save();
            }),
          ],
          const SizedBox(width: 8),
          SizedBox(
            width: 26,
            child: d.special
                ? const SizedBox.shrink()
                : Tooltip(
                    message: 'gefüllte Absätze dieser View',
                    child: Text(
                      n > 0 ? '$n' : '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.mono,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 11.5,
                        color: t.muted,
                      ),
                    ),
                  ),
          ),
          if (!d.special) ...[
            const SizedBox(width: 4),
            AppButton(
              small: true,
              tooltip:
                  '↻ Recompile: Inhalte dieser View für die GANZE Arbeit neu generieren (ersetzt die bisherigen)',
              onPressed: () => _recompile(d),
              child: const Text('↻'),
            ),
            const SizedBox(width: 4),
            AppButton(
              small: true,
              tooltip:
                  'View löschen — entfernt die View UND ihre Inhalte (Standard-Views kommen über ↺ zurück)',
              onPressed: () => _delete(d),
              child: const Text('🗑'),
            ),
          ] else
            const SizedBox(width: 76),
        ],
      ),
    );
  }

  Widget _moveBtn(
      BookClothTokens t, String label, bool enabled, VoidCallback onTap) {
    return Opacity(
      opacity: enabled ? 1 : .35,
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.borderStrong),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(fontSize: 9, height: 1.4, color: t.ink2)),
          ),
        ),
      ),
    );
  }

  Widget _input(
    BookClothTokens t,
    TextEditingController ctl, {
    String? hint,
    String? tooltip,
    ValueChanged<String>? onChanged,
  }) {
    final field = TextField(
      controller: ctl,
      onChanged: onChanged,
      style: AppTextStyles.form.copyWith(fontSize: 13, color: t.ink),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: AppTextStyles.form.copyWith(fontSize: 13, color: t.muted),
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.borderStrong),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: t.accent, width: 2),
          borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: field) : field;
  }

  /// Σ-Auswahl: LaTeX-Material einer Quelle als übergeordnete Textbasis.
  Widget _texSelect(BookClothTokens t, StudioDomain? domain,
      List<String> texSrcs, String current, ValueChanged<String> onPick) {
    final options = [
      ...{...texSrcs, if (current.isNotEmpty) current},
    ];
    return Tooltip(
      message:
          'Σ übergeordnete Verknüpfung: das LaTeX-Material dieser Quelle wird Textbasis der View-Generierung',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          style: AppTextStyles.small.copyWith(fontSize: 12, color: t.ink2),
          dropdownColor: t.surface,
          borderRadius: BorderRadius.circular(7),
          items: [
            const DropdownMenuItem(value: '', child: Text('Σ —')),
            for (final sid in options)
              DropdownMenuItem(
                value: sid,
                child: Text('Σ ${domain?.ctx.srcShort(sid) ?? sid}'),
              ),
          ],
          onChanged: (v) => onPick(v ?? ''),
        ),
      ),
    );
  }
}

/// Farb-Punkt mit Popover (`.ie-colors`/`.ie-sw`): „ohne“ + Token-Swatches +
/// freie #Hex-Farbe. Spezial-Views behalten ihren festen Ton (nur Anzeige).
class _ColorSwatchButton extends StatefulWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.css,
    required this.special,
    required this.onPick,
  });

  final Color color;
  final String css;
  final bool special;
  final ValueChanged<String> onPick;

  @override
  State<_ColorSwatchButton> createState() => _ColorSwatchButtonState();
}

class _ColorSwatchButtonState extends State<_ColorSwatchButton> {
  final OverlayPortalController _pop = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final TextEditingController _hex = TextEditingController();

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    final dot = Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color,
        border: Border.all(color: t.borderStrong, width: 1.5),
      ),
    );
    if (widget.special) return dot;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _pop,
        overlayChildBuilder: (context) => Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _pop.hide,
                ),
              ),
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(0, 6),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 250,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.surface,
                      border: Border.all(color: t.borderStrong),
                      borderRadius:
                          BorderRadius.circular(BookClothTokens.radius),
                      boxShadow: t.shadowPop,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            Tooltip(
                              message: 'ohne Farbe',
                              child: _sw(t, null, widget.css.isEmpty,
                                  () => _apply('')),
                            ),
                            for (final (label, css) in kViewColorTokens)
                              Tooltip(
                                message: label,
                                child: _sw(
                                  t,
                                  resolveCssColor(t, css),
                                  widget.css == css,
                                  () => _apply(css),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _hex,
                                style: AppTextStyles.mono
                                    .copyWith(fontSize: 12, color: t.ink),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: '#c05f5f — freie Farbe',
                                  hintStyle: AppTextStyles.small
                                      .copyWith(fontSize: 11.5, color: t.muted),
                                  filled: true,
                                  fillColor: t.surface2,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: t.borderStrong),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: t.accent),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onSubmitted: _applyHex,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppButton(
                              small: true,
                              onPressed: () => _applyHex(_hex.text),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        child: Tooltip(
          message: 'Farbe der View — Token-Swatches oder freie #Hex-Farbe',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(onTap: _pop.show, child: dot),
          ),
        ),
      ),
    );
  }

  void _apply(String css) {
    widget.onPick(css);
    _pop.hide();
  }

  void _applyHex(String raw) {
    var v = raw.trim();
    if (v.isEmpty) return;
    if (!v.startsWith('#')) v = '#$v';
    if (!RegExp(r'^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$').hasMatch(v)) return;
    _apply(v.toLowerCase());
  }

  Widget _sw(BookClothTokens t, Color? c, bool selected, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c ?? t.surface2,
            border: Border.all(
              color: selected ? t.accentInk : t.borderStrong,
              width: selected ? 2 : 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// ↻-Prompt-Dialog (Welle-1-Pfad „ohne Zugang“): Prompt ansehen + ⧉ kopieren.
class _PromptDialog extends StatefulWidget {
  const _PromptDialog({required this.label, required this.prompt});

  final String label;
  final String prompt;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BookClothTokens.radiusLg)),
      child: Container(
        width: 640,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('↻ ${widget.label} — Prompt',
                style: AppTextStyles.h3.copyWith(color: t.ink)),
            const SizedBox(height: 6),
            Text(
              'Prompt extern ausführen (GPT/Claude), die JSON-Antwort dann über '
              'den GPT-Hub oben einfügen (🎛 Instanzen: ⭱ einfügen).',
              style: AppTextStyles.small.copyWith(color: t.muted),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.surface2,
                border: Border.all(color: t.border),
                borderRadius: BorderRadius.circular(BookClothTokens.radiusSm),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.prompt,
                  style: AppTextStyles.mono
                      .copyWith(fontSize: 11.5, height: 1.5, color: t.ink2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  small: true,
                  variant: AppButtonVariant.primary,
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: widget.prompt));
                    if (mounted) setState(() => _copied = true);
                  },
                  child: Text(_copied ? '✔ kopiert' : '⧉ Prompt kopieren'),
                ),
                const SizedBox(width: 6),
                AppButton(
                  small: true,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
