import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/care/care_pill.dart';
import '../../../shared/widgets/care/care_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../application/family_providers.dart';
import '../data/family_repository.dart';
import '../domain/family_link.dart';

/// Shared by both roles: an elder invites/manages caregivers here, a caregiver invites/
/// manages elders here. The underlying API and permission model (Phase 2) are identical.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isElder = user?.role == AppRole.elder;
    final links = ref.watch(familyLinksProvider);

    return Scaffold(
      appBar: AppBar(title: Text(isElder ? 'Family & Caregivers' : 'Your Elders')),
      body: SafeArea(
        child: links.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(familyLinksProvider)),
          data: (list) {
            if (user == null) return const LoadingView();
            if (list.isEmpty) {
              return CareEmptyState(
                icon: Icons.diversity_3,
                title: isElder ? 'No caregivers linked yet.' : 'No loved one connected yet.',
                message: isElder
                    ? 'Invite a caregiver using the email of their Sathi account.'
                    : 'Invite the person you care for using the email of their Sathi account.',
                actionLabel: isElder ? 'Invite Caregiver' : 'Invite Elder',
                actionIcon: Icons.person_add,
                onAction: () => _showInviteDialog(context, ref, isElder: isElder),
              );
            }
            return list.isEmpty
                ? Center(
                    child: Text(
                      isElder ? 'No caregivers linked yet.\nInvite one below.' : 'No elders linked yet.\nInvite one below.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => ref.invalidate(familyLinksProvider),
                    child: ListView.separated(
                      // Bottom padding keeps the last card clear of the floating Invite button.
                      padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _LinkCard(link: list[i], viewerId: user.id),
                    ),
                  );
          },
        ),
      ),
      // On the empty state the invite action is in the centre already.
      floatingActionButton: (links.value?.isEmpty ?? false)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showInviteDialog(context, ref, isElder: isElder),
              icon: const Icon(Icons.person_add),
              label: Text(isElder ? 'Invite Caregiver' : 'Invite Elder'),
            ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref, {required bool isElder}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isElder ? "Invite a caregiver" : 'Invite an elder'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email address',
                errorText: error,
                helperText: isElder ? "The caregiver's account email" : "The elder's account email",
              ),
              validator: Validators.email,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                try {
                  await ref.read(familyRepositoryProvider).invite(controller.text.trim());
                  ref.invalidate(familyLinksProvider);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (e) {
                  setState(() => error = AppFailure.fromError(e).message);
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkCard extends ConsumerStatefulWidget {
  const _LinkCard({required this.link, required this.viewerId});
  final FamilyLink link;
  final String viewerId;

  @override
  ConsumerState<_LinkCard> createState() => _LinkCardState();
}

class _LinkCardState extends ConsumerState<_LinkCard> {
  bool _isSubmitting = false;

  Future<void> _act(Future<void> Function(String) action) async {
    setState(() => _isSubmitting = true);
    try {
      await action(widget.link.id);
      ref.invalidate(familyLinksProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(e).message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _revoke() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove this link?',
      message: '${widget.link.counterpartLabel(widget.viewerId)} will no longer be able to see shared information.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (confirmed) await _act((id) => ref.read(familyRepositoryProvider).revoke(id));
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final repo = ref.read(familyRepositoryProvider);
    final isInvitedParty = link.isInvitedParty(widget.viewerId);
    final name = link.counterpartLabel(widget.viewerId);

    final header = Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: CareColors.primarySoft, shape: BoxShape.circle),
          child: Text(
            name.characters.first.toUpperCase(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CareColors.primaryDark),
          ),
        ),
        const SizedBox(width: CareSpacing.md),
        Expanded(
          child: Text(name, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: CareSpacing.sm),
        _StatusChip(status: link.status),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(CareSpacing.lg + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 12),
            if (link.status == FamilyLinkStatus.pending && isInvitedParty)
              Row(
                children: [
                  Expanded(
                    child: BigButton(label: 'Accept', icon: Icons.check, isLoading: _isSubmitting, onPressed: () => _act(repo.accept)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BigOutlinedButton(label: 'Decline', icon: Icons.close, onPressed: _isSubmitting ? null : () => _act(repo.decline)),
                  ),
                ],
              )
            else if (link.status == FamilyLinkStatus.pending)
              Text('Waiting for a response...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))
            else if (link.status == FamilyLinkStatus.accepted)
              BigOutlinedButton(label: 'Remove', icon: Icons.link_off, onPressed: _isSubmitting ? null : _revoke),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final FamilyLinkStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
    FamilyLinkStatus.accepted => const CareStatusPill(label: 'Connected'),
    FamilyLinkStatus.pending => const CareStatusPill(label: 'Pending', foreground: CareColors.warning, background: CareColors.warningSoft),
    FamilyLinkStatus.declined => const CareStatusPill(label: 'Declined', foreground: CareColors.neutral, background: CareColors.neutralSoft),
    FamilyLinkStatus.revoked => const CareStatusPill(label: 'Removed', foreground: CareColors.neutral, background: CareColors.neutralSoft),
  };
}
