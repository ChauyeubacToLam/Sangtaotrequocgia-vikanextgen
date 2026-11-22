// Premium Ivory — LIGHT theme color tokens.
//
// Locked design. Values come straight from the master UI system prompt
// (canonical source). Do not edit without updating that spec first.
//
// Architectural rules baked into these values:
//   • Pure black (#000000) is forbidden. All "black" is warm-dark #1F1812.
//   • Pure white (#FFFFFF) is forbidden on cream surfaces. Use bgRaised.
//   • Yellow is reserved for the four uses: stat / dot / underline / CTA.

import 'package:flutter/material.dart';

abstract final class VikaLightColors {
  // ─── Surfaces ───
  static const Color bg = Color(0xFFFFFFFF); // cream
  static const Color bgRaised = Color(0xFFF6F7FC); // raised card on cream
  static const Color bgInverse = Color(0xFF231E5C); // warm-dark hero
  static const Color bgInverseHi = Color(0xFF2E2880); // warm charcoal hero alt
  static const Color powder = Color(0xFFF1F2F9); // tinted cream

  // ─── Ink (always warm, never pure black) ───
  static const Color ink = Color(0xFF1E1B4B);

  /// Secondary text. Use for eyebrows, captions, supporting copy that
  /// carries information. AAA on every cream surface (7.34:1 on bg).
  static const Color inkSoft = Color(0xFF6B6890);

  /// **DECORATIVE ONLY.** Fails WCAG AA at small text sizes (3.22:1 on cream).
  /// Do not use for informational text content (eyebrows, captions, labels,
  /// hints carrying meaning). For secondary text, use [inkSoft] (7.34:1 AAA).
  /// Acceptable uses: swipe indicators, dashed dividers, truly ornamental
  /// micro-marks where readability is irrelevant.
  static const Color inkFaint = Color(0xFF8E8BAE);

  /// Pure decoration: dashed-divider tones, ghosted week-day numerals
  /// for rest days, low-presence indicators. Never text.
  static const Color inkGhost = Color(0xFFD3D5E3);

  // ─── Inverse ink (on warm-dark surfaces) ───
  static const Color invInk = Color(0xFFFFFFFF);
  static Color get invInkSoft => invInk.withValues(alpha: 0.72);
  static Color get invInkFaint => invInk.withValues(alpha: 0.42);

  // ─── Borders ───
  static const Color border = Color(0xFFE3E4F0);
  static const Color borderHi = Color(0xFFD3D5E3);
  static Color get borderDark => invInk.withValues(alpha: 0.10);

  // ─── Yellow (reserved: stat / dot / underline / CTA) ───
  static const Color yellow = Color(0xFF2B5CE6);
  static const Color yellowInk = Color(0xFFFFFFFF);
  static Color get yellowGhost => yellow.withValues(alpha: 0.14);

  // ─── Status ───
  static const Color attention = Color(0xFFFF8A1F);
  static const Color live = Color(0xFF3CC35A);

  static const Color bmiLow = Color(0xFF2B5CE6);
  static const Color bmiGood = Color(0xFF3CC35A);
  static const Color bmiWarn = Color(0xFFFF8A1F);
  static const Color bmiHigh = Color(0xFFE5484D);

  // ─── Phase accents (used SPARINGLY for phase identity) ───
  static const Color phase1 = Color(0xFF3CC35A); // sage — Khởi đầu
  static const Color phase2 = Color(0xFF2B5CE6); // amber — Củng cố
  static const Color phase3 = Color(0xFFFF8A1F); // earth — Đẩy mạnh
  static const Color phase4 = Color(0xFF7C5CFF); // dusk — Đỉnh cao
}
