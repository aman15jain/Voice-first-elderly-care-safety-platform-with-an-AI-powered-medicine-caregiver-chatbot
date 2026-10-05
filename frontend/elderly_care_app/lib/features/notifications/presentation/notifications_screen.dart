import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../shared/widgets/care/care_states.dart';
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
          data: (list) {
            if (list.isEmpty) {
              return const CareEmptyState(
                icon: Icons.notifications_none,
                title: 'No notifications yet.',
                message: "Missed doses and other updates about your loved ones will appear here.",
              );
            }
            final unread = list.where((n) => n.isUnread).length;
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(notificationsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.xs, CareSpacing.screenH - 4, CareSpacing.xl),
                itemCount: list.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: CareSpacing.md),
                itemBuilder: (context, i) => i == 0
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: CareSpacing.xs),
                        child: Text(unread == 0 ? "You're all caught up." : '$unread unread', style: CareText.cardBody),
                      )
                    : _NotificationCard(notification: list[i - 1]),
              ),
            );
          },
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
    final sos = notification.type == AppNotificationType.emergencySos;
    final time = DateFormat.yMMMd().add_jm().format(notification.createdAt);
    final unread = notification.isUnread;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: unread ? const Color(0xFFF3F9F5) : CareColors.surface,
        borderRadius: BorderRadius.circular(CareRadius.card),
        border: Border.all(color: unread ? CareColors.primaryTint : const Color(0x1A0F5C45)),
        boxShadow: CareShadows.tile,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CareSpacing.lg, CareSpacing.lg, CareSpacing.sm, CareSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: sos ? const Color(0xFFFDECEA) : CareColors.accentWarmSoft, borderRadius: BorderRadius.circular(16)),
                  child: Icon(sos ? Icons.sos : Icons.medication_outlined, size: 26, color: sos ? const Color(0xFFC62828) : CareColors.accentWarm),
                ),
                if (unread)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: CareSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title, style: CareText.cardTitle.copyWith(fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(notification.body, style: CareText.cardBody.copyWith(fontSize: 15.5)),
                  const SizedBox(height: 6),
                  Text(time, style: const TextStyle(fontSize: 13.5, color: CareColors.textMuted)),
                ],
              ),
            ),
            unread
                ? IconButton(
                    icon: const Icon(Icons.mark_email_read_outlined),
                    tooltip: 'Mark as read',
                    color: CareColors.primaryDark,
                    onPressed: () async {
                      await ref.read(notificationsRepositoryProvider).markRead(notification.id);
                      ref.invalidate(notificationsProvider);
                    },
                  )
                : const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.check, color: CareColors.primary, semanticLabel: 'Read'),
                  ),
          ],
        ),
      ),
    );
  }
}
