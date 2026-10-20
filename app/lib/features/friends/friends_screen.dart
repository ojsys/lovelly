import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../config/clock.dart';
import '../../theme/icons.dart';
import '../../theme/tokens.dart';
import '../../widgets/avatar.dart';
import 'friends_controller.dart';

/// 07 Friends & inbox — design/screens/07-Inbox.dc.html (FR-16).
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  late int _tab = widget.initialTab;
  bool _searching = false;
  String _query = '';

  bool _matches(String name) => name.toLowerCase().contains(_query.toLowerCase());

  Future<void> _openRequest(FriendRequestRow r) async {
    final accept = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: KColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KRadius.xxl)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(name: r.sender.firstName, photoUrl: r.sender.photoUrl, size: 56),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          r.sender.firstName,
                          if (r.sender.age != null) '${r.sender.age}',
                        ].join(', '),
                        style: KType.cardTitle,
                      ),
                      Text(
                        [
                          if (r.sender.city.isNotEmpty) r.sender.city,
                          if (r.metOn != null) 'met on ${r.metOn}',
                        ].join(' · '),
                        style: KType.body.copyWith(color: KColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.xl),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept'),
            ),
            const SizedBox(height: KSpacing.md),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Decline'),
            ),
          ],
        ),
      ),
    );
    if (accept == null) return;
    final controller = ref.read(friendsControllerProvider.notifier);
    accept ? await controller.accept(r.id) : await controller.decline(r.id);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(friendsControllerProvider);
    final friends = data.value?.friends ?? const <FriendRow>[];
    final requests = data.value?.requests ?? const <FriendRequestRow>[];
    final online = friends.where((f) => f.online).toList();
    final shown = friends.where((f) => _matches(f.friend.firstName)).toList();
    final top = MediaQuery.viewPaddingOf(context).top;
    final now = ref.watch(clockProvider)();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, math.max(52, top + 8), 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _searching
                    ? TextField(
                        autofocus: true,
                        style: KType.input,
                        decoration: const InputDecoration(hintText: 'Search friends'),
                        onChanged: (v) => setState(() => _query = v),
                      )
                    : Text('Friends', style: KType.title),
              ),
              const SizedBox(width: KSpacing.md),
              Semantics(
                button: true,
                label: _searching ? 'Close search' : 'Search friends',
                excludeSemantics: true,
                child: Material(
                  color: KColors.surface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() {
                      _searching = !_searching;
                      _query = '';
                    }),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: _searching
                            ? const KIconView(KIcon.close, size: 20, color: KColors.text)
                            : const KIconView(KIcon.search, size: 20, color: KColors.text),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (online.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('ONLINE NOW', style: KType.label.copyWith(color: KColors.muted)),
            const SizedBox(height: 10),
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: online.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final f = online[i];
                  return InkWell(
                    onTap: () => context.push('/friends/chat/${f.chatId}'),
                    child: Column(
                      children: [
                        Avatar(
                          name: f.friend.firstName,
                          photoUrl: f.friend.photoUrl,
                          size: 56,
                          online: true,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          f.friend.firstName,
                          style: KType.small.copyWith(height: 1.2, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 20),
          _Tabs(tab: _tab, requests: requests.length, onPick: (t) => setState(() => _tab = t)),
          const SizedBox(height: 20),
          Expanded(
            child: data.isLoading && data.value == null
                ? const Center(child: CircularProgressIndicator(color: KColors.coral))
                : _tab == 0
                ? (shown.isEmpty
                      ? _Empty(
                          friends.isEmpty
                              ? 'No friends yet. Tap “Add friend” when you click with someone.'
                              : 'No friends match “$_query”.',
                        )
                      : ListView.separated(
                          itemCount: shown.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, i) => _ChatRow(
                            row: shown[i],
                            now: now,
                            onTap: () => context.push('/friends/chat/${shown[i].chatId}'),
                          ),
                        ))
                : (requests.isEmpty
                      ? const _Empty('No friend requests right now.')
                      : ListView.separated(
                          itemCount: requests.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, i) => _RequestRow(
                            row: requests[i],
                            now: now,
                            onTap: () => _openRequest(requests[i]),
                          ),
                        )),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tab, required this.requests, required this.onPick});

  final int tab;
  final int requests;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: KColors.surface,
      borderRadius: BorderRadius.circular(KRadius.lg),
    ),
    child: Row(
      children: [
        for (final (i, label) in [
          'Chats',
          requests > 0 ? 'Requests · $requests' : 'Requests',
        ].indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: tab == i,
              child: Material(
                color: tab == i ? KColors.text : KColors.transparent,
                borderRadius: BorderRadius.circular(KRadius.sm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(KRadius.sm),
                  onTap: () => onPick(i),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        label,
                        style: KType.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tab == i ? KColors.background : KColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.row, required this.now, required this.onTap});

  final FriendRow row;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = row.lastMessage;
    final preview = last == null
        ? 'Say hi 👋'
        : last.kind == 'system'
        ? last.body
        : last.mine
        ? 'You: ${last.body}'
        : last.body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Avatar(name: row.friend.firstName, photoUrl: row.friend.photoUrl),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.friend.firstName,
                            style: KType.button.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (last != null)
                          Text(
                            chatTime(context, last.sentAt, now: now),
                            style: KType.small.copyWith(height: 1.2, color: KColors.muted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KType.body.copyWith(color: KColors.muted),
                    ),
                  ],
                ),
              ),
              if (row.unread > 0) ...[
                const SizedBox(width: KSpacing.sm),
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: KColors.coral,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '${row.unread}',
                    semanticsLabel: '${row.unread} unread',
                    style: KType.small.copyWith(
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: KColors.onCoral,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.row, required this.now, required this.onTap});

  final FriendRequestRow row;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(KRadius.md),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          Avatar(name: row.sender.firstName, photoUrl: row.sender.photoUrl),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.sender.firstName,
                        style: KType.button.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      chatTime(context, row.createdAt, now: now),
                      style: KType.small.copyWith(height: 1.2, color: KColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Wants to be friends${row.metOn != null ? ' · met on ${row.metOn}' : ''}',
                  style: KType.body.copyWith(color: KColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(KSpacing.xl),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: KType.bodyLarge.copyWith(color: KColors.muted),
      ),
    ),
  );
}
