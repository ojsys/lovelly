import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A person's main photo, or their initial on a colour picked from their name.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.photoUrl, this.size = 52, this.online = false});

  final String name;
  final String? photoUrl;
  final double size;

  /// Mint "online now" dot (07).
  final bool online;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();
    final color = KColors
        .avatarPalette[name.codeUnits.fold(0, (a, b) => a + b) % KColors.avatarPalette.length];
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: photoUrl == null
          ? Text(
              initial,
              style: KType.input.copyWith(fontWeight: FontWeight.w700, fontSize: size / 3),
            )
          : Image.network(
              photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(initial, style: KType.input),
            ),
    );
    if (!online) return circle;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          circle,
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: KColors.mint,
                shape: BoxShape.circle,
                border: Border.all(color: KColors.background, width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "2:16 PM", "Yesterday", "Mon", or "12 Oct" (07 chat rows).
String chatTime(BuildContext context, DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(local);
  final days = today.difference(day).inDays;
  final l10n = MaterialLocalizations.of(context);
  if (days == 0) return l10n.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  if (days == 1) return 'Yesterday';
  if (days < 7) return const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][local.weekday % 7];
  return l10n.formatShortMonthDay(local);
}
