import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/care_tokens.dart';
import '../../../shared/widgets/care/care_pill.dart';
import '../data/health_repository.dart';
import '../domain/health_status.dart';

/// Phase 1 placeholder: proves Flutter -> Node -> (Postgres, Python AI) connectivity.
/// Replaced by the real Splash/Home flow in later phases.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(backendHealthProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sathi')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(CareSpacing.screenH - 4, CareSpacing.sm, CareSpacing.screenH - 4, CareSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Connection check', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              health.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const _StatusRow(label: 'Server', ok: false),
                data: (h) => Card(
                  child: Column(
                    children: [
                      const _StatusRow(label: 'Server', ok: true),
                      _StatusRow(label: 'Database', ok: h.database == DependencyState.up),
                      _StatusRow(label: 'AI service', ok: h.aiService == DependencyState.up),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(onPressed: () => ref.invalidate(backendHealthProvider), child: const Text('Check again')),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = ok ? (CareColors.success, CareColors.successSoft) : (CareColors.danger, CareColors.dangerSoft);
    return Semantics(
      label: '$label ${ok ? 'working' : 'not available'}',
      excludeSemantics: true,
      child: ListTile(
        leading: CareIconTile(icon: ok ? Icons.check_circle : Icons.cancel, color: fg, background: bg, size: 44),
        title: Text(label),
        trailing: CareStatusPill(label: ok ? 'Working' : 'Not available', foreground: fg, background: bg),
      ),
    );
  }
}
