import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/notifications_providers.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

/// A caregiver's feed of missed-dose (and, in future, other) alerts — distinct from the
/// Alerts tab, which is specifically active SOS events that need an immediate response.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: notifications.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(notificationsProvider)),
          data: (list) => list.isEmpty
              ? const Center(child: Text('No notifications yet.', style: TextStyle(fontSize: 20)))
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(notificationsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _NotificationCard(notification: list[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = notification.type == AppNotificationType.emergencySos ? Icons.warning_amber : Icons.medication_outlined;
    final time = DateFormat.yMMMd().add_jm().format(notification.createdAt);

    return Card(
      color: notification.isUnread ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(notification.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.body),
            const SizedBox(height: 4),
            Text(time, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
        trailing: notification.isUnread
            ? IconButton(
                icon: const Icon(Icons.mark_email_read_outlined),
                tooltip: 'Mark as read',
                onPressed: () async {
                  await ref.read(notificationsRepositoryProvider).markRead(notification.id);
                  ref.invalidate(notificationsProvider);
                },
              )
            : const Icon(Icons.check, color: Colors.grey),
      ),
    );
  }
}
