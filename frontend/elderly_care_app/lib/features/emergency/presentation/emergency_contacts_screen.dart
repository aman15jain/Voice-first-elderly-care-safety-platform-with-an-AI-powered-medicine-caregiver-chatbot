import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../data/emergency_repository.dart';
import '../domain/emergency_contact.dart';

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: SafeArea(
        child: contacts.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: AppFailure.fromError(e).message, onRetry: () => ref.invalidate(emergencyContactsProvider)),
          data: (list) => list.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No emergency contacts yet.\nAdd someone to call when it matters most.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => _ContactCard(contact: list[i]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final relationship = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => Validators.required(v, message: 'Please enter a name'),
                ),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  validator: (v) => Validators.required(v, message: 'Please enter a phone number'),
                ),
                TextFormField(controller: relationship, decoration: const InputDecoration(labelText: 'Relationship (optional)')),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                try {
                  await ref
                      .read(emergencyRepositoryProvider)
                      .createContact(name: name.text.trim(), phone: phone.text.trim(), relationship: relationship.text.trim());
                  ref.invalidate(emergencyContactsProvider);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (e) {
                  setState(() => error = AppFailure.fromError(e).message);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends ConsumerStatefulWidget {
  const _ContactCard({required this.contact});
  final EmergencyContact contact;

  @override
  ConsumerState<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends ConsumerState<_ContactCard> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove Contact?',
      message: 'Remove ${widget.contact.name} from your emergency contacts?',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(emergencyRepositoryProvider).deleteContact(widget.contact.id);
      ref.invalidate(emergencyContactsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppFailure.fromError(e).message)));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.person, size: 36),
        title: Text(widget.contact.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        subtitle: Text(
          [widget.contact.relationship, widget.contact.phone].where((s) => s != null && s.isNotEmpty).join(' • '),
          style: const TextStyle(fontSize: 16),
        ),
        trailing: _isDeleting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
      ),
    );
  }
}
