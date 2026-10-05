import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/care_tokens.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(child: user == null ? const SizedBox.shrink() : _SathiProfile(user: user)),
    );
  }
}

/// Sathi profile (both roles): header card, then grouped account / preference cards.
class _SathiProfile extends StatelessWidget {
  const _SathiProfile({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final initial = user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';
    final role = user.role == AppRole.elder ? 'Elder' : 'Caregiver';

    return ListView(
      padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, CareSpacing.xl),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE6F3EC), Color(0xFFF7FBF8)]),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: CareShadows.tile,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CareSpacing.lg, vertical: CareSpacing.xl),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CareColors.primaryDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: CareShadows.tile,
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(height: CareSpacing.md),
                Semantics(
                  header: true,
                  child: Text(user.displayName, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                ),
                const SizedBox(height: CareSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: CareColors.surface, borderRadius: BorderRadius.circular(CareRadius.pill)),
                  child: Text(
                    role,
                    style: TextStyle(fontSize: Theme.of(context).textTheme.bodySmall?.fontSize, fontWeight: FontWeight.w800, color: CareColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CareSpacing.xl),
        const _GroupLabel('Account'),
        Card(
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.email_outlined), title: const Text('Email'), subtitle: Text(user.email)),
              const Divider(height: 1, indent: CareSpacing.lg, endIndent: CareSpacing.lg),
              ListTile(leading: const Icon(Icons.language), title: const Text('Language'), subtitle: Text(user.preferredLanguage.toUpperCase())),
            ],
          ),
        ),
        const SizedBox(height: CareSpacing.lg),
        const _GroupLabel('Preferences'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            subtitle: const Text('Alerts, language and sign out'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings'),
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(CareSpacing.xs, 0, 0, CareSpacing.sm),
    child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
  );
}
