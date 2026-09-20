import 'package:flutter/material.dart';

/// Shown instead of the app when `.env` still holds the placeholder values, so
/// a fresh clone explains itself rather than crashing on startup.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supabase is not configured',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Open the .env file in the project root and set '
                    'SUPABASE_URL and SUPABASE_ANON_KEY to the values from '
                    'your Supabase dashboard (Project Settings → API). Then '
                    'stop the app and run it again.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
