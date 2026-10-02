import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family_repository.dart';
import '../domain/family_link.dart';

final familyLinksProvider = FutureProvider.autoDispose<List<FamilyLink>>((ref) {
  return ref.watch(familyRepositoryProvider).listLinks();
});
