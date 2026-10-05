import 'package:flutter/material.dart';

import 'care/care_states.dart';

/// Shown instead of a raw exception whenever loading data fails. [message] should
/// already be friendly — see core/errors/app_failure.dart. Renders the shared Sathi
/// [CareErrorState].
class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => CareErrorState(message: message, onRetry: onRetry);
}
