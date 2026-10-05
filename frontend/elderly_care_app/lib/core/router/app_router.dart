import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/role_selection_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/caregiver_onboarding/presentation/caregiver_intro_screen.dart';
import '../../features/caregiver_onboarding/presentation/caregiver_welcome_screen.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/emergency/presentation/caregiver_emergency_screen.dart';
import '../../features/emergency/presentation/emergency_contacts_screen.dart';
import '../../features/emergency/presentation/sos_screen.dart';
import '../../features/family/presentation/family_screen.dart';
import '../../features/games/domain/game_models.dart';
import '../../features/games/presentation/attention_exercise_screen.dart';
import '../../features/games/presentation/games_screen.dart';
import '../../features/games/presentation/memory_match_screen.dart';
import '../../features/games/presentation/pattern_recognition_screen.dart';
import '../../features/games/presentation/sequence_recall_screen.dart';
import '../../features/health/presentation/health_screen.dart';
import '../../features/home/presentation/caregiver_home_screen.dart';
import '../../features/home/presentation/elder_home_screen.dart';
import '../../features/medicines/domain/medicine_models.dart';
import '../../features/medicines/presentation/add_medicine_screen.dart';
import '../../features/medicines/presentation/medicine_details_screen.dart';
import '../../features/medicines/presentation/medicine_history_screen.dart';
import '../../features/medicines/presentation/medicines_screen.dart';
import '../../features/medicines/presentation/todays_schedule_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/voice/presentation/voice_screen.dart';
import '../../shared/widgets/care/care_page_transition.dart';
import '../storage/token_storage.dart';
import 'app_shell.dart';

const _elderTabs = [
  ShellDestination(path: '/home', icon: Icons.home, label: 'Home'),
  ShellDestination(path: '/medicines', icon: Icons.medication, label: 'Medicines'),
  ShellDestination(path: '/family', icon: Icons.diversity_3, label: 'Family'),
  ShellDestination(path: '/profile', icon: Icons.person, label: 'Profile'),
];

const _caregiverTabs = [
  ShellDestination(path: '/caregiver', icon: Icons.home, label: 'Home'),
  ShellDestination(path: '/caregiver/family', icon: Icons.diversity_3, label: 'Elders'),
  ShellDestination(path: '/caregiver/alerts', icon: Icons.warning_amber, label: 'Alerts'),
  ShellDestination(path: '/caregiver/notifications', icon: Icons.notifications_none, label: 'Notices'),
  ShellDestination(path: '/caregiver/profile', icon: Icons.person, label: 'Profile'),
];

const _publicPaths = ['/login', '/role-selection', '/register', '/welcome'];

final appRouterProvider = Provider<GoRouter>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);

  return GoRouter(
    initialLocation: '/splash',
    // A coarse safety net (e.g. logout from anywhere): screens navigate explicitly after
    // login/register/logout themselves, so this mostly guards direct/deep navigation.
    refreshListenable: tokenStorage.isAuthenticated,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (authState is AuthBootstrapping) {
        return loc == '/splash' ? null : '/splash';
      }

      final isPublic = _publicPaths.any(loc.startsWith);
      if (authState is AuthUnauthenticated) {
        return isPublic ? null : '/login';
      }

      final role = (authState as AuthAuthenticated).user.role;
      final home = role == AppRole.caregiver ? '/caregiver' : '/home';
      if (isPublic || loc == '/splash') return home;
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/role-selection', builder: (context, state) => const RoleSelectionScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(role: state.extra as AppRole? ?? AppRole.elder),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      // Caregiver onboarding (2 steps): /welcome → /welcome/intro → the existing /login.
      GoRoute(path: '/welcome', builder: (context, state) => const CaregiverWelcomeScreen()),
      GoRoute(
        path: '/welcome/intro',
        pageBuilder: (context, state) => careOnboardingPage(key: state.pageKey, child: const CaregiverIntroScreen()),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      // Phase 1 connectivity check, kept reachable for diagnostics.
      GoRoute(path: '/diagnostics', builder: (context, state) => const HealthScreen()),

      GoRoute(path: '/voice', builder: (context, state) => const VoiceScreen()),
      GoRoute(path: '/games', builder: (context, state) => const GamesScreen()),
      GoRoute(
        path: '/games/memory-match',
        builder: (context, state) => MemoryMatchScreen(game: state.extra as CognitiveGame),
      ),
      GoRoute(
        path: '/games/pattern-recognition',
        builder: (context, state) => PatternRecognitionScreen(game: state.extra as CognitiveGame),
      ),
      GoRoute(
        path: '/games/attention-exercise',
        builder: (context, state) => AttentionExerciseScreen(game: state.extra as CognitiveGame),
      ),
      GoRoute(
        path: '/games/sequence-recall',
        builder: (context, state) => SequenceRecallScreen(game: state.extra as CognitiveGame),
      ),
      GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen()),
      GoRoute(path: '/emergency', builder: (context, state) => const SosScreen()),
      GoRoute(path: '/emergency/contacts', builder: (context, state) => const EmergencyContactsScreen()),

      // Declared before /medicines/:id: go_router matches routes in order, and a literal
      // segment must be tried before a param segment can wrongly swallow it.
      GoRoute(path: '/medicines/add', builder: (context, state) => const AddMedicineScreen()),
      GoRoute(path: '/medicines/today', builder: (context, state) => const TodaysScheduleScreen()),
      GoRoute(path: '/medicines/history', builder: (context, state) => const MedicineHistoryScreen()),
      GoRoute(
        path: '/medicines/:id',
        builder: (context, state) => MedicineDetailsScreen(medicine: state.extra as Medicine),
      ),

      ShellRoute(
        builder: (context, state, child) => AppShell(currentPath: state.matchedLocation, destinations: _elderTabs, child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const ElderHomeScreen()),
          GoRoute(path: '/medicines', builder: (context, state) => const MedicinesScreen()),
          GoRoute(path: '/family', builder: (context, state) => const FamilyScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(currentPath: state.matchedLocation, destinations: _caregiverTabs, child: child),
        routes: [
          GoRoute(path: '/caregiver', builder: (context, state) => const CaregiverHomeScreen()),
          GoRoute(path: '/caregiver/family', builder: (context, state) => const FamilyScreen()),
          GoRoute(path: '/caregiver/alerts', builder: (context, state) => const CaregiverEmergencyScreen()),
          GoRoute(path: '/caregiver/notifications', builder: (context, state) => const NotificationsScreen()),
          GoRoute(path: '/caregiver/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
