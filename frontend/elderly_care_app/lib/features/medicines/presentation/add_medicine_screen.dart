import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/big_button.dart';
import '../application/medicines_providers.dart';
import '../data/medicines_repository.dart';

const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// The time picker shows/collects the device's local time, but the backend stores
/// "HH:mm" in UTC (see docs/architecture.md's documented timezone simplification), so
/// the picked time is converted here. Known remaining edge case: a time near local
/// midnight can convert to a different UTC calendar day than intended, because the
/// backend doesn't track a per-elder timezone to correct for that.
String _toUtcHHmm(TimeOfDay time) {
  final now = DateTime.now();
  final utc = DateTime(now.year, now.month, now.day, time.hour, time.minute).toUtc();
  return '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}';
}

/// One screen creates the medicine and its schedule together — fewer steps for an
/// elder than a separate "add schedule" screen afterwards (see spec section 20).
class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dosage = TextEditingController();
  final _instructions = TextEditingController();
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];
  final Set<int> _selectedDays = {}; // empty = every day
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(context: context, initialTime: _times[index]);
    if (picked != null) setState(() => _times[index] = picked);
  }

  void _addTime() => setState(() => _times.add(const TimeOfDay(hour: 20, minute: 0)));
  void _removeTime(int index) => setState(() => _times.removeAt(index));

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(medicinesRepositoryProvider);
      final medicine = await repo.createMedicine(
        name: _name.text.trim(),
        dosage: _dosage.text.trim(),
        instructions: _instructions.text.trim(),
      );
      await repo.createSchedule(
        medicineId: medicine.id,
        timesOfDay: _times.map(_toUtcHHmm).toList(),
        daysOfWeek: _selectedDays.toList()..sort(),
        startDate: DateTime.now(),
      );
      ref.invalidate(medicinesListProvider);
      ref.invalidate(todayDosesProvider);
      ref.invalidate(adherenceSummaryProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = AppFailure.fromError(e).message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Medicine')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Medicine Name', prefixIcon: Icon(Icons.medication)),
                  validator: (v) => Validators.required(v, message: 'Please enter the medicine name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dosage,
                  decoration: const InputDecoration(labelText: 'Dosage', hintText: 'e.g. 500mg, 2 tablets', prefixIcon: Icon(Icons.scale)),
                  validator: (v) => Validators.required(v, message: 'Please enter the dosage'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructions,
                  decoration: const InputDecoration(labelText: 'Instructions (optional)', hintText: 'e.g. after food'),
                ),
                const SizedBox(height: 28),
                Text('What time?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < _times.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(i),
                            icon: const Icon(Icons.access_time),
                            label: Text(_times[i].format(context), style: const TextStyle(fontSize: 20)),
                          ),
                        ),
                        if (_times.length > 1)
                          IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _removeTime(i)),
                      ],
                    ),
                  ),
                TextButton.icon(onPressed: _addTime, icon: const Icon(Icons.add), label: const Text('Add another time', style: TextStyle(fontSize: 18))),
                const SizedBox(height: 20),
                Text('What days?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Every day'),
                      selected: _selectedDays.isEmpty,
                      onSelected: (_) => setState(_selectedDays.clear),
                    ),
                    for (var d = 0; d < 7; d++)
                      FilterChip(
                        label: Text(_weekdayLabels[d]),
                        selected: _selectedDays.contains(d),
                        onSelected: (selected) => setState(() => selected ? _selectedDays.add(d) : _selectedDays.remove(d)),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 20),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 18), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 28),
                BigButton(label: 'Save Medicine', icon: Icons.check, onPressed: _submit, isLoading: _isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
