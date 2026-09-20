import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:major_project/models/app_user.dart';
import 'package:major_project/providers/auth_provider.dart';
import 'package:major_project/providers/onboarding_provider.dart';
import 'package:major_project/routes/app_routes.dart';
import 'package:major_project/utils/snackbar.dart';
import 'package:major_project/utils/validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole? _role;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final service = ref.read(supabaseServiceProvider);
    final onboardingPending = ref.read(onboardingPendingProvider.notifier);
    setState(() => _loading = true);

    // Set before signing up: the moment the session arrives, the router reads
    // this flag to choose between onboarding and home.
    onboardingPending.set(true);
    try {
      final response = await service.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: _role!,
      );
      // With a session, the router moves the user on by itself. Without one,
      // the project requires email confirmation first.
      if (response.session == null && mounted) {
        showSnackBar(
          context,
          'Account created. Check your email to confirm it, then log in.',
        );
        context.go(AppRoutes.login);
      }
    } on AuthException catch (e) {
      onboardingPending.set(false);
      if (mounted) showSnackBar(context, e.message);
    } catch (_) {
      onboardingPending.set(false);
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
      appBar: AppBar(title: const Text('Create account')),
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
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: Validators.newPassword,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'I am signing up as',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildRoleField(context),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text('Already have an account? Log in'),
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

  /// No role is preselected: picking one is a deliberate choice, and the form
  /// won't submit until it is made.
  Widget _buildRoleField(BuildContext context) {
    return FormField<UserRole>(
      validator: (_) => _role == null ? 'Please choose a role' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<UserRole>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              for (final role in UserRole.values)
                ButtonSegment(value: role, label: Text(role.label)),
            ],
            selected: {?_role},
            onSelectionChanged: (selection) {
              setState(() => _role = selection.firstOrNull);
              field.didChange(_role);
            },
          ),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12),
              child: Text(
                field.errorText!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
