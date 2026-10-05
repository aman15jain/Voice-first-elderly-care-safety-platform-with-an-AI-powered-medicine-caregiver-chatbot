import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/care_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/domain/app_user.dart';

class ElderlyCareApp extends ConsumerWidget {
  const ElderlyCareApp({super.key});

  static final _standardTheme = CareTheme.data();
  static final _comfortTheme = CareTheme.data(comfort: true);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One Sathi design system everywhere; while an elder is signed in it uses the
    // comfort sizing (larger type, 64dp buttons).
    final auth = ref.watch(authControllerProvider);
    final isElder = auth is AuthAuthenticated && auth.user.role == AppRole.elder;

    return MaterialApp.router(title: 'Sathi', theme: isElder ? _comfortTheme : _standardTheme, routerConfig: ref.watch(appRouterProvider));
  }
}
