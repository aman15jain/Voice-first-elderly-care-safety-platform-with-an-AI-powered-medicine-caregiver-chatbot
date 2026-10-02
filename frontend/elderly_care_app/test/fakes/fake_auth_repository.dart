import 'package:dio/dio.dart';
import 'package:elderly_care_app/core/storage/token_storage.dart';
import 'package:elderly_care_app/features/auth/data/auth_repository.dart';
import 'package:elderly_care_app/features/auth/domain/app_user.dart';

/// Extends the real repository (rather than implementing an interface) and overrides
/// every method that would otherwise touch the network, so the unused Dio instances
/// passed to `super` are never actually invoked.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository(this._tokenStorage) : super(Dio(), Dio(), _tokenStorage);

  final TokenStorage _tokenStorage;
  AppUser userToReturn = const AppUser(id: 'u1', email: 'elder@example.com', role: AppRole.elder, preferredLanguage: 'en', fullName: 'Rose');
  Object? errorToThrow;

  @override
  Future<void> login({required String email, required String password}) async {
    if (errorToThrow != null) throw errorToThrow!;
    await _tokenStorage.save(accessToken: 'fake-access', refreshToken: 'fake-refresh');
  }

  @override
  Future<void> register({required String email, required String password, required AppRole role, required String fullName}) async {
    if (errorToThrow != null) throw errorToThrow!;
    await _tokenStorage.save(accessToken: 'fake-access', refreshToken: 'fake-refresh');
  }

  @override
  Future<void> logout() async => _tokenStorage.clear();

  @override
  Future<AppUser> fetchProfile() async => userToReturn;

  @override
  Future<bool> updateNotificationPreferences({required bool notifyOnMissedDose}) async {
    userToReturn = AppUser(
      id: userToReturn.id,
      email: userToReturn.email,
      role: userToReturn.role,
      preferredLanguage: userToReturn.preferredLanguage,
      fullName: userToReturn.fullName,
      notifyOnMissedDose: notifyOnMissedDose,
    );
    return notifyOnMissedDose;
  }
}
