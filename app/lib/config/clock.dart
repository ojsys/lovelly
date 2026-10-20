import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now", overridable so time-dependent UI (Home's greeting) is testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
