import 'package:flutter/material.dart';

import 'big_button.dart';

/// Shown instead of a raw exception whenever loading data fails. [message] should
/// already be elder-friendly — see core/errors/app_failure.dart.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              SizedBox(width: 220, child: BigButton(label: 'Try Again', icon: Icons.refresh, onPressed: onRetry)),
            ],
          ],
        ),
      ),
    );
  }
}
