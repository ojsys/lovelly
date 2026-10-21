import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lovelly/api/api.dart';
import 'package:lovelly/auth/onboarding_repository.dart';
import 'package:lovelly/auth/session.dart';
import 'package:lovelly/auth/token_store.dart';

import '../helpers/fakes.dart';

const _compose = '../infra/docker-compose.yml';

/// A fresh Nigerian mobile number for each run. Wide enough that numbers banned by earlier
/// runs (M4 tests) don't come back.
String newPhone() {
  final r = Random();
  const prefixes = ['0803', '0806', '0813', '0816', '0903', '0706'];
  return '${prefixes[r.nextInt(prefixes.length)]}${r.nextInt(9000000) + 1000000}';
}

Future<String> codeFor(String phone) async {
  final e164 = '+234${phone.substring(1)}';
  for (var i = 0; i < 20; i++) {
    final logs = await Process.run('docker', [
      'compose',
      '-f',
      _compose,
      'logs',
      'api',
      '--since',
      '2m',
    ]);
    final match = RegExp(
      'fake sms code for ${RegExp.escape(e164)}: (\\d{6})',
    ).allMatches(logs.stdout as String).lastOrNull;
    if (match != null) return match.group(1)!;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw StateError('no code logged for $e164');
}

Future<String> jpeg() async {
  final file = File('${Directory.systemTemp.createTempSync('lovelly').path}/pose.jpg');
  await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(64, 0x30)]);
  return file.path;
}

/// One simulated device: its own token store and provider container.
class Device {
  Device() : store = FakeTokenStore() {
    container = ProviderContainer(overrides: [tokenStoreProvider.overrideWithValue(store)]);
  }

  final FakeTokenStore store;
  late final ProviderContainer container;

  OnboardingRepository get repo => container.read(onboardingRepositoryProvider);

  Future<SessionState> session() => container.read(sessionProvider.future);

  Future<void> signIn(String phone) async {
    await session();
    final sent = await repo.requestCode(phone, ChannelEnum.sms);
    await container
        .read(sessionProvider.notifier)
        .signedIn(await repo.verifyCode(sent.phone, await codeFor(phone)));
  }

  /// Phone → basics → selfie: a verified user (SF-1).
  Future<void> onboard(String name, {GenderEnum gender = GenderEnum.other}) async {
    await signIn(newPhone());
    await repo.setBasics(firstName: name, dob: DateTime(1998, 5, 1), gender: gender);
    final pose = await jpeg();
    await repo.submitSelfie(front: pose, left: pose);
  }

  void dispose() => container.dispose();
}
