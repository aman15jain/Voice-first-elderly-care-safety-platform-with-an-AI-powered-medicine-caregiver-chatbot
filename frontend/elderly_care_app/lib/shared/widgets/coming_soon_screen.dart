import 'package:flutter/material.dart';

/// Honest placeholder for a feature whose phase hasn't arrived yet (voice, cognitive
/// games, emergency SOS). It never pretends to work — it says plainly what's missing.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({required this.title, required this.description, super.key, this.icon = Icons.hourglass_top});

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(description, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
