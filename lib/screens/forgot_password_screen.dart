import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:major_project/providers/auth_provider.dart';
import 'package:major_project/routes/app_routes.dart';
import 'package:major_project/utils/snackbar.dart';
import 'package:major_project/utils/validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final service = ref.read(supabaseServiceProvider);
    final email = _emailController.text.trim();
    setState(() => _loading = true);
    try {
      await service.sendPasswordResetEmail(email);
      if (!mounted) return;
      // Worded so it doesn't reveal whether an account exists for this email.
      showSnackBar(
        context,
        'If an account exists for $email, a reset link is on its way.',
      );
      context.go(AppRoutes.login);
    } on AuthException catch (e) {
      if (mounted) showSnackBar(context, e.message);
    } catch (_) {
      if (mounted) {
        showSnackBar(context, 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter the email you signed up with and we will send '
                      'you a link to reset your password.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: Validators.email,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send reset link'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text('Back to log in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
