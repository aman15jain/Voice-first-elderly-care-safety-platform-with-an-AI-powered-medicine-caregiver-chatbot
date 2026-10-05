import 'package:flutter/material.dart';

import 'care/care_states.dart';

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
        child: CareEmptyState(icon: icon, title: title, message: description),
      ),
    );
  }
}
