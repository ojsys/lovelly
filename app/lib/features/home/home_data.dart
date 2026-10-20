import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../platform/permissions.dart';

/// First name, interests etc. for Home and Matching (`GET me/profile`).
final myProfileProvider = FutureProvider<MyProfile>(
  (ref) => ref.watch(apiProvider).me.meProfileRetrieve(),
);

/// People online now (FR-9), refreshed every 15 s while watched.
final onlineCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  final api = ref.watch(apiProvider);
  while (true) {
    try {
      yield (await api.match.matchOnlineCountRetrieve()).count;
    } catch (_) {
      // Keep the last value; try again on the next tick.
    }
    await Future<void>.delayed(const Duration(seconds: 15));
  }
});

/// FR-5: video and voice need camera and mic; without them only text works.
final callsAllowedProvider = FutureProvider.autoDispose<({bool video, bool voice})>((ref) async {
  final gateway = ref.watch(permissionGatewayProvider);
  final camera = await gateway.status(DevicePermission.camera) == GrantState.granted;
  final mic = await gateway.status(DevicePermission.microphone) == GrantState.granted;
  return (video: camera && mic, voice: mic);
});
