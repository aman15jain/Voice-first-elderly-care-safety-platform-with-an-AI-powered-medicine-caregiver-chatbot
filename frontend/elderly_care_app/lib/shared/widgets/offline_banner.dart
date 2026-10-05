import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/theme/care_tokens.dart';

/// A persistent, unmissable strip — not a toast that disappears — because an elder or
/// caregiver needs to know *for as long as it's true* that actions may not be reaching the
/// server, not just at the moment connectivity dropped.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    // Loading/error reads as "assume online" — we only want to show this when we've
    // positively confirmed there's no connectivity, never while we're still finding out.
    final offline = isOnline.when(data: (online) => !online, loading: () => false, error: (_, _) => false);
    if (!offline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: CareColors.warning,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're offline. Some information may be out of date.",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
