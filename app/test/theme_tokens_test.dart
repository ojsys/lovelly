import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CLAUDE.md: colours and fonts live in theme tokens; never hard-code them in widgets.
void main() {
  final banned = <String, RegExp>{
    'colour literal': RegExp(r'Color\(0x|Color\.fromARGB|Color\.fromRGBO|\bColors\.'),
    'font family literal': RegExp(r'''fontFamily:\s*['"]'''),
  };

  test('no colour or font literals outside lib/theme/', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.startsWith('lib/theme/'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final MapEntry(key: what, value: pattern) in banned.entries) {
          if (pattern.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1} $what');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'Use KColors / KFonts / KType instead.');
  });
}
