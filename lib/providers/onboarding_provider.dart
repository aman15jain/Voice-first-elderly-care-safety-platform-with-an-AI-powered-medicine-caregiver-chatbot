import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True between a successful signup and the user leaving the onboarding screen.
///
/// The router reads this to send new users to onboarding instead of home. It
/// lives in memory only: there is no persisted "onboarding done" flag yet.
class OnboardingPending extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final onboardingPendingProvider = NotifierProvider<OnboardingPending, bool>(
  OnboardingPending.new,
);
