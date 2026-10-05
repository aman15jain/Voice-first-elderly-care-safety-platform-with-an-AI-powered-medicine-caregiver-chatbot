import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/care/care_states.dart';
import '../../../shared/widgets/care/care_connect_logo.dart';
import '../application/auth_controller.dart';
import '../domain/app_user.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(email: _email.text.trim(), password: _password.text);
      if (mounted) {
        final authState = ref.read(authControllerProvider);
        final role = authState is AuthAuthenticated ? authState.user.role : AppRole.elder;
        context.go(role == AppRole.caregiver ? '/caregiver' : '/home');
      }
    } catch (e) {
      setState(() => _error = AppFailure.fromError(e).message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: CareSpacing.screenH, vertical: CareSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandLockup(),
                    const SizedBox(height: CareSpacing.xl),
                    Text('Welcome Back', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: CareSpacing.sm),
                    const Text('Sign in to continue to Sathi.', style: CareText.body, textAlign: TextAlign.center),
                    const SizedBox(height: CareSpacing.xxl),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => Validators.required(v, message: 'Please enter your password'),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[const SizedBox(height: 16), CareInlineError(message: _error!)],
                    const SizedBox(height: 28),
                    BigButton(label: 'Log In', onPressed: _submit, isLoading: _isLoading),
                    const SizedBox(height: 16),
                    TextButton(onPressed: () => context.push('/role-selection'), child: const Text('New here? Create an account')),
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

/// Sathi mark + wordmark, centred — the same brand lockup as the onboarding pages.
class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: CareConnectLogo.brandName,
      excludeSemantics: true,
      child: Column(
        children: [
          const CareConnectMark(size: 64),
          const SizedBox(height: CareSpacing.sm),
          Text(CareConnectLogo.brandName, style: CareText.brandName.copyWith(fontSize: 30, color: CareColors.primary)),
        ],
      ),
    );
  }
}
