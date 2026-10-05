import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/care_tokens.dart';
import '../domain/app_user.dart';

/// The first screen of registration: who is this account for? Kept as its own step
/// (rather than a field in the form) so the choice is unmissable — see spec section 33.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Who is this account for?', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: CareSpacing.sm),
              const Text('Choose the one that fits — you can invite family later.', style: CareText.body, textAlign: TextAlign.center),
              const SizedBox(height: CareSpacing.xxl),
              _RoleCard(
                icon: Icons.person,
                title: 'I am an Elder',
                subtitle: 'Manage my own medicines and care',
                onTap: () => context.push('/register', extra: AppRole.elder),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.diversity_3,
                title: 'I am a Caregiver',
                subtitle: 'Support a family member',
                onTap: () => context.push('/register', extra: AppRole.caregiver),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: CareColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                child: Icon(icon, size: 32, color: CareColors.primary),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
