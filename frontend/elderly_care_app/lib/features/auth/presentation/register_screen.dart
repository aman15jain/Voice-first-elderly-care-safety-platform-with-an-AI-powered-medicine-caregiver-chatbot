import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/care_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/big_button.dart';
import '../../../shared/widgets/care/care_states.dart';
import '../application/auth_controller.dart';
import '../domain/app_user.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({required this.role, super.key});
  final AppRole role;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullName.dispose();
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
      await ref
          .read(authControllerProvider.notifier)
          .register(email: _email.text.trim(), password: _password.text, role: widget.role, fullName: _fullName.text.trim());
      if (mounted) context.go(widget.role == AppRole.caregiver ? '/caregiver' : '/home');
    } catch (e) {
      setState(() => _error = AppFailure.fromError(e).message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = widget.role == AppRole.caregiver ? 'Caregiver' : 'Elder';
    return Scaffold(
      appBar: AppBar(title: Text('$roleLabel Account')),
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
                    TextFormField(
                      controller: _fullName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge)),
                      validator: (v) => Validators.required(v, message: 'Please enter your name'),
                    ),
                    const SizedBox(height: 16),
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
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: 'At least 8 characters, with a letter and a number',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    if (_error != null) ...[const SizedBox(height: 16), CareInlineError(message: _error!)],
                    const SizedBox(height: 28),
                    BigButton(label: 'Create Account', onPressed: _submit, isLoading: _isLoading),
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
