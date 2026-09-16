import 'package:flutter/material.dart';

/// Display font for titles and item/upgrade names — Cinzel, bundled locally
/// (assets/fonts/Cinzel-Variable.ttf) rather than fetched via google_fonts
/// at runtime: emulator/device DNS isn't guaranteed at first launch, and a
/// bundled font never depends on network at all. Stands in for the game's
/// eventual custom typography, used everywhere the mockups show ornate
/// lettering (SHOP, LEVEL UP!, card names, the CONTINUE button). Body copy
/// (descriptions, chip labels) stays on the default Material font for
/// readability at small sizes.
TextStyle fantasyText({
  required double fontSize,
  required Color color,
  FontWeight fontWeight = FontWeight.w700,
  double letterSpacing = 1,
}) {
  return TextStyle(
    fontFamily: 'Cinzel',
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
  );
}
