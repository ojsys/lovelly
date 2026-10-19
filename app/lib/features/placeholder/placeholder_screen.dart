import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';

/// Stand-in for a screen whose milestone hasn't started yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.number,
    required this.title,
    required this.milestone,
  });

  final String number;
  final String title;
  final String milestone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.canPop() ? context.pop() : null,
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              Text(number, style: KType.label.copyWith(color: KColors.muted)),
              const SizedBox(height: KSpacing.sm),
              Text(title, style: KType.title),
              const SizedBox(height: KSpacing.sm),
              Text('Arrives in $milestone.', style: KType.bodyLarge.copyWith(color: KColors.muted)),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
