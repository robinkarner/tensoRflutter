/// Suchbegriff-Chips — Port der `sw-chip`-Zeilen (:1079-1099, :1573-1586):
/// „⧉“ kopiert alle Begriffe (900ms „✔“-Feedback), „🔎 `<Begriff>`“ startet
/// die PDF-Volltextsuche über den [onSearch]-Rückruf.
///
/// Die Begriffe kommen aus `U.searchTerms` (Port unten): bevorzugt an
/// `| · ;` getrennte WÖRTLICHE Passagen (≥3 Zeichen), sonst Einzelwörter
/// ≥4 Zeichen, dedupliziert, max. 8.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

/// Port von `U.searchTerms` (util.js:291-296).
List<String> searchTerms(String? hinweis) {
  final s = (hinweis ?? '').trim();
  if (s.isEmpty) return const [];
  if (RegExp(r'[|·;]').hasMatch(s)) {
    return [
      for (final t in s.split(RegExp(r'\s*[|·;]\s*')))
        if (t.trim().length >= 3) t.trim(),
    ].take(8).toList();
  }
  final seen = <String>{};
  return [
    for (final w in s.split(RegExp(r'\s+')))
      if (w.length >= 4 && seen.add(w)) w,
  ].take(8).toList();
}

class SearchChips extends StatefulWidget {
  const SearchChips({
    super.key,
    required this.suchHinweis,
    required this.onSearch,
    this.maxTermLength = 34,
  });

  final String suchHinweis;
  final void Function(String term) onSearch;

  /// Kürzung des Chip-Labels (Beleg-Zeile: 30, Dock: 34).
  final int maxTermLength;

  @override
  State<SearchChips> createState() => _SearchChipsState();
}

class _SearchChipsState extends State<SearchChips> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: widget.suchHinweis));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _SwChip(
          label: _copied ? '✔' : '⧉',
          tooltip: 'Alle Suchbegriffe kopieren',
          bold: true,
          onTap: _copyAll,
        ),
        for (final w in searchTerms(widget.suchHinweis))
          _SwChip(
            label:
                '🔎 ${w.length > widget.maxTermLength ? '${w.substring(0, widget.maxTermLength - 1)}…' : w}',
            tooltip: '„$w“ im PDF suchen (Enter im Suchfeld: weitere Treffer)',
            onTap: () => widget.onSearch(w),
          ),
      ],
    );
  }
}

class _SwChip extends StatefulWidget {
  const _SwChip({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.bold = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool bold;

  @override
  State<_SwChip> createState() => _SwChipState();
}

class _SwChipState extends State<_SwChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = BookClothTokens.of(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: _hover ? t.accentSoft : t.surface2,
              border: Border.all(color: _hover ? t.accentLine : t.border),
              borderRadius: BorderRadius.circular(BookClothTokens.radiusPill),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontFamilyFallback: AppFonts.fallback,
                fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
                height: 1,
                color: _hover ? t.accentInk : t.ink2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
