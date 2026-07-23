/// `.sf-iconbtn` (app.css:456-463): 32×32-Icon-Knopf der Spalten-Kopfzeilen
/// (⇤/⇥/⤢ …) — von Kapitelbaum und Quellen-Spalte geteilt.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';

class SfIconBtn extends StatefulWidget {
  const SfIconBtn({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<SfIconBtn> createState() => _SfIconBtnState();
}

class _SfIconBtnState extends State<SfIconBtn> {
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
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? t.surface3 : t.surface2,
              border: Border.all(color: _hover ? t.accent : t.borderStrong),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(widget.icon,
                style: TextStyle(
                  fontSize: 15,
                  height: 1,
                  color: _hover ? t.ink : t.ink2,
                  fontFamilyFallback: AppFonts.fallback,
                )),
          ),
        ),
      ),
    );
  }
}
