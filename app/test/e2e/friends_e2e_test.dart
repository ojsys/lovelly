/// M5 acceptance against the running stack (`make up`): a friend request round-trip between
/// two real clients, then a message to a friend whose app is closed arrives as a push.
///
///   flutter test --tags e2e --run-skipped test/e2e/friends_e2e_test.dart
@Tags(['e2e'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lovelly/features/friends/friends_repository.dart';
import 'package:lovelly/features/match/match_controller.dart';
import 'package:lovelly/realtime/realtime_client.dart';

import 'support.dart';

Future<void> until(bool Function() ok, {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!ok()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('condition not met', timeout);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

/// The fake push provider logs each push it "sends" (core/providers/push.py).
Future<String> pushLogFor(String token, {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  final pattern = RegExp('fake push to ${RegExp.escape(token.substring(0, 8))}…: (.*)');
  while (DateTime.now().isBefore(deadline)) {
    final logs = await Process.run('docker', [
      'compose', '-f', '../infra/docker-compose.yml', 'logs', 'api', 'worker', '--since', '2m', //
    ]);
    final match = pattern.allMatches(logs.stdout as String).lastOrNull;
    if (match != null) return match.group(1)!;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
  throw TimeoutException('no push logged for $token', timeout);
}

void main() {
  late Device a, b;

  setUp(() async {
    a = Device();
    b = Device();
    await a.onboard('Ada');
    await b.onboard('Kwame');
  });

  tearDown(() {
    a.dispose();
    b.dispose();
  });

  MatchState st(Device d) => d.container.read(matchControllerProvider);
  MatchController ctl(Device d) => d.container.read(matchControllerProvider.notifier);
  FriendsRepository friends(Device d) => d.container.read(friendsRepositoryProvider);
  RealtimeClient rt(Device d) => d.container.read(realtimeClientProvider);

  test('M5: friend request round-trip, then a push to a friend whose app is closed '
      '(FR-14, FR-16, FR-17)', () async {
    final aEvents = <String>[], bEvents = <String>[];
    rt(a).events.listen((e) => aEvents.add('${e['type']}'));
    rt(b).events.listen((e) => bEvents.add('${e['type']}'));

    await ctl(a).start(MatchMode.video);
    await ctl(b).start(MatchMode.video);
    await until(() => st(a).phase == MatchPhase.matched && st(b).phase == MatchPhase.matched);
    final sessionId = st(a).sessionId!;

    // A taps "Add friend" during the call; B gets it live and accepts.
    await friends(a).request(sessionId);
    await until(() => bEvents.contains('friend.request'));
    final request = (await friends(b).friends()).requests.single;
    expect(request.sender.firstName, 'Ada');
    expect(request.metOn, 'video');
    await friends(b).accept(request.id);
    await until(() => aEvents.contains('friend.accepted') && bEvents.contains('friend.accepted'));

    final aList = (await friends(a).friends()).friends;
    final bList = (await friends(b).friends()).friends;
    expect(aList.single.friend.firstName, 'Kwame');
    expect(bList.single.friend.firstName, 'Ada');
    expect(aList.single.chatId, bList.single.chatId);
    final chatId = aList.single.chatId;
    ctl(a).end();

    // B registers this install for push, then closes the app (no websocket).
    final token = 'e2e${Random().nextInt(90000) + 10000}-${DateTime.now().millisecondsSinceEpoch}';
    await friends(b).registerDevice('android', token);
    await rt(b).stop();
    await Future<void>.delayed(const Duration(seconds: 1));

    rt(a).send({'type': 'chat.message', 'chat_id': chatId, 'body': 'Na you be this?'});
    final push = await pushLogFor(token);
    // Lock screen shows no message text (M5 decision 3); the tap opens the chat.
    expect(push, contains('Ada sent you a message'));
    expect(push, isNot(contains('Na you be this?')));
    expect(push, contains("'type': 'chat'"));
    expect(push, contains("'chat_id': '$chatId'"));
    // ignore: avoid_print
    print('push: $push');
  });

  test('M5: calling a friend rings them, and answering connects both (FR-16)', () async {
    final bEvents = <Map<String, dynamic>>[];
    rt(b).events.listen(bEvents.add);
    st(a);
    st(b); // match controllers listen for match.found

    // Become friends (as above, without the checks).
    await ctl(a).start(MatchMode.text);
    await ctl(b).start(MatchMode.text);
    await until(() => st(a).phase == MatchPhase.matched && st(b).phase == MatchPhase.matched);
    await friends(a).request(st(a).sessionId!);
    await until(() => bEvents.any((e) => e['type'] == 'friend.request'));
    await friends(b).accept((await friends(b).friends()).requests.single.id);
    final chatId = (await friends(a).friends()).friends.single.chatId;
    ctl(a).end();
    await until(() => st(a).phase == MatchPhase.idle && st(b).phase != MatchPhase.matched);
    ctl(b).cancel();

    rt(a).send({'type': 'call.invite', 'chat_id': chatId, 'mode': 'voice'});
    await until(() => bEvents.any((e) => e['type'] == 'call.incoming'));
    final incoming = bEvents.lastWhere((e) => e['type'] == 'call.incoming');
    expect(incoming['chat_id'], chatId);
    expect((incoming['from'] as Map)['first_name'], 'Ada');

    final started = DateTime.now();
    rt(b).send({'type': 'call.accept', 'invite_id': incoming['invite_id']});
    await until(() => st(a).phase == MatchPhase.matched && st(b).phase == MatchPhase.matched);
    expect(st(a).chatId, chatId);
    expect(st(b).chatId, chatId);
    expect(st(a).mode, MatchMode.voice);
    expect(st(a).mediaToken, isNotNull);
    ctl(a).end();
    // ignore: avoid_print
    print('friend call connected in ${DateTime.now().difference(started).inMilliseconds} ms');
  });
}
