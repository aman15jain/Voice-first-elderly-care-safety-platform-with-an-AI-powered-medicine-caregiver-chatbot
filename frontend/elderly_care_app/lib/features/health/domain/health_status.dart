enum DependencyState { up, down }

class BackendHealth {
  const BackendHealth({required this.ok, required this.database, required this.aiService});

  /// Backend reachable at all.
  final bool ok;
  final DependencyState database;
  final DependencyState aiService;

  bool get fullyHealthy => ok && database == DependencyState.up && aiService == DependencyState.up;
}
