/// ＋ Neue Quelle anlegen (views_quellen.js:147-201) und ＋ Quelle aus Datei
/// erstellen (js:293-326) — die beiden Anlage-Modals mit Live-id-Vorschlag
/// und Slug-Sanitizing.
///
/// Statt `mergeCustomSources + rebuildDataIndexes` läuft nach dem Anlegen
/// der E8-Reboot (die Runtime mischt customSources beim Boot ein); die
/// Navigation zur neuen Quellenseite übernimmt der Aufrufer-Callback.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/modal.dart';
import '../../../data/bundles/indexes.dart';
import '../../../data/repos/file_store.dart';
import '../../../data/repos/project_repository.dart';
import 'source_id_logic.dart';

/// ＋ Neue Quelle anlegen. [onCreated] läuft nach Anlegen + Reboot mit der
/// neuen id (Aufrufer navigiert zur Quellenseite).
void showNewSourceModal(BuildContext context, {void Function(String id)? onCreated}) {
  showAppModal(
    context,
    title: const Text('＋ Neue Quelle anlegen'),
    body: _NewSourceBody(onCreated: onCreated),
  );
}

class _NewSourceBody extends ConsumerStatefulWidget {
  const _NewSourceBody({this.onCreated});

  final void Function(String id)? onCreated;

  @override
  ConsumerState<_NewSourceBody> createState() => _NewSourceBodyState();
}

class _NewSourceBodyState extends ConsumerState<_NewSourceBody> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _year = TextEditingController();
  final _container = TextEditingController();
  final _doi = TextEditingController();
  final _id = TextEditingController();
  String _kind = kindLabels.keys.first;
  bool _idTouched = false;
  String _msg = '';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_title, _author, _year, _container, _doi, _id]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Live-Vorschlag (js:166-171) — stoppt, sobald das id-Feld berührt wurde.
  void _suggestId() {
    if (_idTouched) return;
    _id.text = suggestNewSourceId(
      author: _author.text,
      title: _title.text,
      year: _year.text,
    );
  }

  Future<void> _save() async {
    final id = sanitizeSourceId(_id.text);
    final title = _title.text.trim();
    if (id.isEmpty || title.isEmpty) {
      setState(() => _msg = '✗ id und Titel sind Pflicht.');
      return;
    }
    if (ref.read(srcByIdProvider).containsKey(id)) {
      setState(() => _msg = '✗ id „$id“ existiert schon.');
      return;
    }
    setState(() => _busy = true);
    final doi = _doi.text.trim();
    await ref.read(projectRepositoryProvider).saveCustomSource({
      'id': id,
      'title': title,
      'kind': _kind,
      'author': _author.text.trim(),
      'year': int.tryParse(_year.text),
      'container': _container.text.trim(),
      // DOI-Feld heuristisch verteilen (js:190-191).
      'doi': RegExp(r'^10\.').hasMatch(doi) ? doi : null,
      'url': RegExp(r'^https?:').hasMatch(doi) ? doi : null,
    });
    await ref.read(projectBootProvider.notifier).reboot();
    closeAppModal();
    widget.onCreated?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    Widget label(String text, Widget field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: AppTextStyles.small.copyWith(color: t.ink2)),
            const SizedBox(height: 3),
            field,
          ],
        );

    TextField input(TextEditingController c, String hint,
            {TextInputType? type, VoidCallback? onInput}) =>
        TextField(
          controller: c,
          keyboardType: type,
          style: AppTextStyles.form.copyWith(color: t.ink),
          decoration: InputDecoration(hintText: hint),
          onChanged: (_) => onInput?.call(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(
                text: 'Für Papers/Quellen, die die Voranalyse nicht kennt — '
                    'z. B. neu gefundene Literatur.\nNach dem Anlegen liefert '),
            const TextSpan(
                text: '🤖 Ergänzung',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(
                text: ' (auf der Quellenseite) einem externen GPT-Modell alles, '
                    'um die Quelle zu finden und Dossier + vermutete '
                    'Zitierstellen nachzutragen.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: label('Titel*',
                  input(_title, 'Titel der Quelle', onInput: _suggestId))),
          const SizedBox(width: 10),
          Expanded(
              child: label('Autor(en)',
                  input(_author, 'Nachname, V. u.a.', onInput: _suggestId))),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 100,
            child: label('Jahr',
                input(_year, '2025', type: TextInputType.number, onInput: _suggestId)),
          ),
          const SizedBox(width: 10),
          Expanded(child: label('Typ', _kindSelect(t))),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: label('Container/Journal', input(_container, 'Journal, Bd., Nr.'))),
          const SizedBox(width: 10),
          Expanded(child: label('DOI oder URL', input(_doi, '10.xxxx/… oder https://…'))),
        ]),
        const SizedBox(height: 10),
        label(
          'id (interner Schlüssel)',
          TextField(
            controller: _id,
            style: AppTextStyles.mono.copyWith(fontSize: 13, color: t.ink),
            decoration:
                const InputDecoration(hintText: 'wird aus Autor+Jahr vorgeschlagen'),
            onChanged: (_) => _idTouched = true,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: _busy ? null : () => unawaited(_save()),
            child: const Text('Anlegen'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_msg, style: AppTextStyles.small.copyWith(color: t.muted)),
          ),
        ]),
      ],
    );
  }

  Widget _kindSelect(BookClothTokens t) => DropdownButton<String>(
        value: _kind,
        isExpanded: true,
        isDense: true,
        style: AppTextStyles.form.copyWith(color: t.ink),
        items: [
          for (final e in kindLabels.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => setState(() => _kind = v ?? _kind),
      );
}

// ---------------------------------------------------------------------------
// ＋ Quelle aus Datei erstellen (Rückrichtung aus der Ablage)
// ---------------------------------------------------------------------------

/// Aus einer noch nicht zugeordneten Datei eine neue Quelle anlegen und die
/// Datei gleich zuweisen (js:293-326). Titel/id sind aus dem Dateinamen
/// vorbelegt und editierbar.
void showSourceFromFileModal(
  BuildContext context, {
  required String name,
  VoidCallback? onDone,
}) {
  showAppModal(
    context,
    title: const Text('＋ Quelle aus Datei erstellen'),
    body: _SourceFromFileBody(name: name, onDone: onDone),
  );
}

class _SourceFromFileBody extends ConsumerStatefulWidget {
  const _SourceFromFileBody({required this.name, this.onDone});

  final String name;
  final VoidCallback? onDone;

  @override
  ConsumerState<_SourceFromFileBody> createState() => _SourceFromFileBodyState();
}

class _SourceFromFileBodyState extends ConsumerState<_SourceFromFileBody> {
  late final TextEditingController _title =
      TextEditingController(text: guessTitleFromFilename(widget.name));
  final _author = TextEditingController();
  final _year = TextEditingController();
  late final TextEditingController _id =
      TextEditingController(text: guessIdFromTitle(guessTitleFromFilename(widget.name)));
  String _kind = 'artikel';
  String _msg = '';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_title, _author, _year, _id]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final id = sanitizeSourceId(_id.text);
    final title = _title.text.trim();
    if (id.isEmpty || title.isEmpty) {
      setState(() => _msg = '✗ id und Titel sind Pflicht.');
      return;
    }
    if (ref.read(srcByIdProvider).containsKey(id)) {
      setState(() => _msg = '✗ id „$id“ existiert schon — dann lieber „→ zuweisen“.');
      return;
    }
    setState(() => _busy = true);
    await ref.read(projectRepositoryProvider).saveCustomSource({
      'id': id,
      'title': title,
      'kind': _kind,
      'author': _author.text.trim(),
      'year': int.tryParse(_year.text),
    });
    final files = await ref.read(fileStoreProvider.future);
    await files.assignInbox(widget.name, id);
    files.resetStatusCache();
    await ref.read(projectBootProvider.notifier).reboot();
    closeAppModal();
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    Widget label(String text, Widget field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: AppTextStyles.small.copyWith(color: t.ink2)),
            const SizedBox(height: 3),
            field,
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Aus '),
            TextSpan(
                text: widget.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(
                text: ' wird eine neue Quelle angelegt und die Datei ihr '
                    'zugewiesen.\nDanach lässt sich die Quelle auf ihrer Seite per '),
            const TextSpan(
                text: '🤖 Ergänzung',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const TextSpan(text: ' vervollständigen.'),
          ]),
          style: AppTextStyles.small.copyWith(color: t.muted),
        ),
        const SizedBox(height: 10),
        label(
          'Titel*',
          TextField(
            controller: _title,
            style: AppTextStyles.form.copyWith(color: t.ink),
          ),
        ),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: label(
              'Autor(en)',
              TextField(
                controller: _author,
                style: AppTextStyles.form.copyWith(color: t.ink),
                decoration: const InputDecoration(hintText: 'Nachname, V. u.a.'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: label(
              'Jahr',
              TextField(
                controller: _year,
                keyboardType: TextInputType.number,
                style: AppTextStyles.form.copyWith(color: t.ink),
                decoration: const InputDecoration(hintText: '2025'),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: label(
              'Typ',
              DropdownButton<String>(
                value: _kind,
                isExpanded: true,
                isDense: true,
                style: AppTextStyles.form.copyWith(color: t.ink),
                items: [
                  for (final e in kindLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: label(
              'id',
              TextField(
                controller: _id,
                style: AppTextStyles.mono.copyWith(fontSize: 13, color: t.ink),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          AppButton(
            variant: AppButtonVariant.primary,
            small: true,
            onPressed: _busy ? null : () => unawaited(_save()),
            child: const Text('Anlegen & zuweisen'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_msg, style: AppTextStyles.small.copyWith(color: t.muted)),
          ),
        ]),
      ],
    );
  }
}
