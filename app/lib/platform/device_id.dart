import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A stable per-device id sent as X-Device-Id, so a ban covers the device and not just
/// the phone number (SF-6). Android: ANDROID_ID (per app-signing key, survives reinstall).
/// iOS: identifierForVendor.
abstract interface class DeviceIdSource {
  Future<String?> deviceId();
}

class SystemDeviceIdSource implements DeviceIdSource {
  String? _cached;

  @override
  Future<String?> deviceId() async {
    if (_cached != null) return _cached;
    try {
      _cached = Platform.isAndroid
          ? await const AndroidId().getId()
          : (await DeviceInfoPlugin().iosInfo).identifierForVendor;
    } catch (_) {
      _cached = null;
    }
    return _cached;
  }
}

final deviceIdSourceProvider = Provider<DeviceIdSource>((ref) => SystemDeviceIdSource());
