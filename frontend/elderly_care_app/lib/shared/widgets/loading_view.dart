import 'package:flutter/material.dart';

import 'care/care_states.dart';

/// Full-screen loading: the shared Sathi skeleton cards, or — when there is a [message] to
/// read — a spinner with that message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const CareListSkeleton();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(message!, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
