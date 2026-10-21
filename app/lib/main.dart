import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, asset) in [
      ('Bricolage Grotesque', 'assets/fonts/BricolageGrotesque-OFL.txt'),
      ('DM Sans', 'assets/fonts/DMSans-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString(asset));
    }
  });
  runApp(const ProviderScope(child: LovellyApp()));
}
