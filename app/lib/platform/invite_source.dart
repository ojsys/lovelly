import 'dart:io';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where an invite code reaches a new install (MN-3, M6 decision 3).
abstract interface class InviteSource {
  /// The code this install came with, if any.
  Future<String?> code();
}

/// Android: the Play Store passes `referrer=invite%3D<CODE>` through to the install.
/// iOS has no install referrer; invites there count only through an app link (later).
class PlayInstallReferrerSource implements InviteSource {
  @override
  Future<String?> code() async {
    if (!Platform.isAndroid) return null;
    try {
      final referrer = (await AndroidPlayInstallReferrer.installReferrer).installReferrer;
      return parseInviteCode(referrer);
    } catch (_) {
      return null; // not installed from Play (debug builds, sideloads)
    }
  }
}

String? parseInviteCode(String? referrer) {
  if (referrer == null || referrer.isEmpty) return null;
  final code = Uri.splitQueryString(Uri.decodeComponent(referrer))['invite'];
  return code != null && RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(code) ? code : null;
}

final inviteSourceProvider = Provider<InviteSource>((ref) => PlayInstallReferrerSource());
