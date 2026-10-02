import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoggingOut = false;
  bool _isSavingPreference = false;

  Future<void> _logout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log Out?',
      message: 'You will need to log in again to use the app.',
      confirmLabel: 'Log Out',
    );
    if (!confirmed) return;
    setState(() => _isLoggingOut = true);
    await ref.read(authControllerProvider.notifier).logout();
    // No explicit navigation: the router's redirect sends unauthenticated users to /login.
  }

  Future<void> _toggleNotifyOnMissedDose(bool value) async {
    setState(() => _isSavingPreference = true);
    try {
      await ref.read(authRepositoryProvider).updateNotificationPreferences(notifyOnMissedDose: value);
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(e).message)));
    } finally {
      if (mounted) setState(() => _isSavingPreference = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final isCaregiver = user?.role == AppRole.caregiver;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.translate),
                  title: Text('Language', style: TextStyle(fontSize: 20)),
                  subtitle: Text('More languages are coming soon.'),
                ),
              ),
              if (isCaregiver) ...[
                const SizedBox(height: 12),
                Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.notifications_active),
                    title: const Text('Missed dose alerts', style: TextStyle(fontSize: 20)),
                    subtitle: const Text('Get notified when a linked elder misses a scheduled dose.'),
                    value: user?.notifyOnMissedDose ?? true,
                    onChanged: _isSavingPreference ? null : _toggleNotifyOnMissedDose,
                  ),
                ),
              ],
              const Spacer(),
              BigButton(
                label: 'Log Out',
                icon: Icons.logout,
                isLoading: _isLoggingOut,
                color: Theme.of(context).colorScheme.error,
                onPressed: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
