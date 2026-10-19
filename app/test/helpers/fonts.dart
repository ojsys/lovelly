import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads every font in the app's FontManifest (app fonts and Material icons), so golden
/// tests render real glyphs instead of the Ahem test font.
Future<void> loadAppFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
