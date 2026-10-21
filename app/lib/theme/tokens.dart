// Design tokens from the Lovelly canvas (design/screens/*.dc.html).
// This file and theme.dart are the only places colours and font families may be written
// (enforced by test/theme_tokens_test.dart).
import 'package:flutter/painting.dart';

/// Colours. The first ten are the PRD palette; the rest are neutrals the canvas uses.
abstract final class KColors {
  static const background = Color(0xFF0F0E13);
  static const surface = Color(0xFF1B1A22);
  static const line = Color(0xFF34313F);
  static const text = Color(0xFFF4F1EA);
  static const muted = Color(0xFFA9A4B6);
  static const coral = Color(0xFFFF6B4A);
  static const gold = Color(0xFFFFC94A);
  static const lilac = Color(0xFFB9A7FF);
  static const mint = Color(0xFF5BE3A1);
  static const danger = Color(0xFFE5484D);

  /// Raised surface (chips, inputs on surface).
  static const surface2 = Color(0xFF26242F);

  /// Text and icons on coral, e.g. primary buttons.
  static const onCoral = Color(0xFF1A0E0B);

  /// Text and icons on gold.
  static const onGold = Color(0xFF1F1600);

  /// Link hover/pressed.
  static const coralPressed = Color(0xFFFF8D73);

  static const transparent = Color(0x00000000);

  /// Coral at 13 % (Matching rings).
  static const coralSoft = Color(0x22FF6B4A);

  /// Voice call accent (05) and its 13 % tint.
  static const lilacSoft = Color(0x22B9A7FF);

  /// Call overlays (04): scrims over video, glass chips and buttons.
  static const scrimTop = Color(0x8C0F0E13);
  static const scrimBottom = Color(0xB30F0E13);
  static const glass = Color(0x29F4F1EA);
  static const glassDark = Color(0x990F0E13);
  static const textOnVideo = Color(0xFFD6D2DE);
  static const white = Color(0xFFFFFFFF);

  /// Report sheet (08): scrim over the paused call, the sheet, and a selected reason.
  static const reportScrim = Color(0xB80F0E13);
  static const sheet = Color(0xFF15141B);
  static const coralSelected = Color(0xFF2A1D1A);

  /// Initial-avatar backgrounds (Friends, 07), picked by name.
  static const avatarPalette = [
    Color(0xFF2E4A44),
    Color(0xFF3B3156),
    Color(0xFF4A3428),
    Color(0xFF2E3A56),
    Color(0xFF44402A),
    Color(0xFF563131),
    Color(0xFF2A4456),
  ];

  /// Bottom navigation bar background.
  static const navBar = Color(0xFF131218);

  /// Gift icon strokes (11) that aren't brand colours: Coffee and Jollof.
  static const giftLatte = Color(0xFFE8B48A);
  static const giftOrange = Color(0xFFFF8D5A);

  /// 11: the call behind the gift sheet, and the "You sent …" pill.
  static const giftScrim = Color(0x730F0E13);
  static const toast = Color(0xBF0F0E13);

  /// 12/13: a selected plan card, and the pay-as-you-go tag.
  static const goldSelected = Color(0xFF261F0E);

  /// 13: Home dimmed behind the charge sheet.
  static const chargeScrim = Color(0xC70F0E13);

  /// Avatar placeholders (initials) and their text.
  static const avatarPlum = Color(0xFF2A2233);
  static const avatarPlumText = Color(0xFFD9D3E6);
  static const avatarIndigo = Color(0xFF262036);

  /// Ink on an accent card at 12 % (Home "Video chat" tag).
  static const onCoralTint = Color(0x1F1A0E0B);

  /// Text on disabled buttons (background is [surface2]).
  static const disabledText = Color(0xFF8A8597);

  /// Camera placeholder (Selfie oval) and its caption.
  static const cameraBackground = Color(0xFF1E2A2A);
  static const cameraText = Color(0xFF8FB0A9);

  /// Photo placeholder tiles (Welcome): background / caption pairs.
  static const tilePlum = Color(0xFF2A2233);
  static const tilePlumText = Color(0xFFD9D3E6);
  static const tileTeal = Color(0xFF1E2A2A);
  static const tileTealText = Color(0xFFCFE3DE);
  static const tileClay = Color(0xFF2E2420);
  static const tileClayText = Color(0xFFEAD8CF);
}

abstract final class KFonts {
  /// Headings.
  static const display = 'BricolageGrotesque';

  /// Body text.
  static const body = 'DMSans';

  /// DM Sans has no naira sign (₦); Bricolage Grotesque supplies it (and any other gap).
  static const bodyFallback = [display];
}

/// Text styles. Sizes, weights, line heights and tracking from the canvas.
abstract final class KType {
  // Headings — Bricolage Grotesque.
  static const hero = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 40,
    height: 1.02,
    letterSpacing: -1,
  );

  /// Selfie screen title (32 px; the other onboarding titles are 34).
  static const titleSmall = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 32,
    height: 1.05,
    letterSpacing: -0.8,
  );
  static const title = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 34,
    height: 1.05,
    letterSpacing: -0.8,
  );

  /// Matching screen title (30 px).
  static const searchTitle = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 30,
    letterSpacing: -0.6,
  );

  /// Bottom-sheet titles (Report, 26 px).
  static const sheetTitle = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 26,
    letterSpacing: -0.5,
  );

  /// Voice call icebreaker question (19 px).
  static const icebreaker = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 19,
    height: 1.25,
  );

  /// Home "Start matching" card.
  static const startCard = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 38,
    height: 1,
    letterSpacing: -1,
  );
  static const wordmark = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 24,
    letterSpacing: -0.5,
  );
  static const cardTitle = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 20,
    height: 1.1,
  );

  // Body — DM Sans.
  static const buttonLarge = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w700,
    fontSize: 17,
  );

  /// Body copy under onboarding titles.
  static const lead = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w400,
    fontSize: 15,
    height: 1.5,
  );
  static const input = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w500,
    fontSize: 16,
  );
  static const code = TextStyle(
    fontFamily: KFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 36,
    letterSpacing: 18,
  );
  static const bodyLarge = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.5,
  );
  static const button = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w500,
    fontSize: 15,
  );
  static const body = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.4,
  );
  static const caption = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w400,
    fontSize: 13,
  );
  static const small = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.5,
  );

  /// Message time and status (11 px).
  static const meta = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w400,
    fontSize: 11,
  );

  /// Uppercase section labels ("6-DIGIT CODE", "WHAT HAPPENED?").
  static const label = TextStyle(
    fontFamily: KFonts.body,
    fontFamilyFallback: KFonts.bodyFallback,
    fontWeight: FontWeight.w700,
    fontSize: 12,
    letterSpacing: 0.8,
  );
}

abstract final class KRadius {
  static const xs = 3.0;
  static const sm = 12.0;
  static const md = 14.0;
  static const lg = 16.0;
  static const xl = 18.0;
  static const xxl = 24.0;
  static const field = 20.0;
}

abstract final class KSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Screen padding used across the canvas (390 × 844 frames).
  static const screen = EdgeInsets.fromLTRB(24, 56, 24, 32);

  /// Onboarding screens (14–17) sit 4 px higher.
  static const onboardingScreen = EdgeInsets.fromLTRB(24, 52, 24, 32);
}
