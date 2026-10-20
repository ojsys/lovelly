import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/icons.dart';
import '../theme/tokens.dart';

/// Bottom navigation: Match / Friends / Profile (Home design, 02).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _tabs = [(KIcon.logo, 'Match'), (KIcon.chat, 'Friends'), (KIcon.person, 'Profile')];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: KColors.navBar,
          border: Border(top: BorderSide(color: KColors.surface2)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, bottom > 0 ? bottom : 26),
          child: Row(
            children: [
              for (final (i, (icon, label)) in _tabs.indexed)
                Expanded(
                  child: Semantics(
                    selected: shell.currentIndex == i,
                    button: true,
                    label: label,
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(KRadius.md),
                      onTap: () => shell.goBranch(i, initialLocation: i == shell.currentIndex),
                      child: SizedBox(
                        height: 48,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            KIconView(
                              icon,
                              color: shell.currentIndex == i ? KColors.text : KColors.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: KType.small.copyWith(
                                height: 1,
                                fontWeight: shell.currentIndex == i
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: shell.currentIndex == i ? KColors.text : KColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
