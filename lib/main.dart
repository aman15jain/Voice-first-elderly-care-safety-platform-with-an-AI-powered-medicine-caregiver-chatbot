import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:major_project/app.dart';
import 'package:major_project/screens/setup_required_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();
  final url = dotenv.maybeGet('SUPABASE_URL');
  final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');

  if (!_isConfigured(url, anonKey)) {
    runApp(const MaterialApp(home: SetupRequiredScreen()));
    return;
  }

  // Restores a persisted session, if there is one, before the first frame.
  // `publishableKey` is the parameter that replaced `anonKey`; the anon key
  // from the Supabase dashboard goes there.
  await Supabase.initialize(url: url!, publishableKey: anonKey!);

  runApp(
    // No automatic retries: a failed request should surface, not spin.
    ProviderScope(retry: (retryCount, error) => null, child: const App()),
  );
}

/// False while `.env` is missing values or still has the placeholder text.
bool _isConfigured(String? url, String? anonKey) {
  if (url == null || anonKey == null || url.isEmpty || anonKey.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(url);
  final validUrl = uri != null && uri.hasScheme && uri.host.isNotEmpty;
  return validUrl && !anonKey.startsWith('your_');
}
