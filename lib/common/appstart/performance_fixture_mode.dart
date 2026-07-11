/// Enables deterministic, offline data paths used only by the profile harness.
///
/// The flag is deliberately opt-in: normal debug, profile, and release builds
/// keep their production refresh behaviour.  The harness supplies its own
/// realistic SQLite/secure-storage fixture and must never wait on a service.
const bool isPerformanceFixtureMode = bool.fromEnvironment(
  'PERF_TEST_OFFLINE_FIXTURES',
  defaultValue: false,
);
