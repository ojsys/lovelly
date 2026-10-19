import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum DevicePermission { camera, microphone, notifications }

enum GrantState { notAsked, granted, denied, permanentlyDenied }

/// Device permission prompts (screen 17), behind an interface so tests can fake them.
abstract interface class PermissionGateway {
  Future<GrantState> status(DevicePermission permission);
  Future<GrantState> request(DevicePermission permission);
  Future<void> openSettings();
}

class SystemPermissionGateway implements PermissionGateway {
  Permission _of(DevicePermission p) => switch (p) {
    DevicePermission.camera => Permission.camera,
    DevicePermission.microphone => Permission.microphone,
    DevicePermission.notifications => Permission.notification,
  };

  GrantState _map(PermissionStatus s) => switch (s) {
    PermissionStatus.granted ||
    PermissionStatus.limited ||
    PermissionStatus.provisional => GrantState.granted,
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => GrantState.permanentlyDenied,
    PermissionStatus.denied => GrantState.notAsked,
  };

  @override
  Future<GrantState> status(DevicePermission p) async => _map(await _of(p).status);

  @override
  Future<GrantState> request(DevicePermission p) async {
    final result = _map(await _of(p).request());
    return result == GrantState.notAsked ? GrantState.denied : result;
  }

  @override
  Future<void> openSettings() => openAppSettings();
}

final permissionGatewayProvider = Provider<PermissionGateway>((ref) => SystemPermissionGateway());
