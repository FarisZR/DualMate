---
title: Reuse dhbw.app canteen payloads across weekly menu loads
date: 2026-06-10
---

# Summary

The dhbw.app canteen source fetches a site-wide payload and derives weekly menus
from it locally. Current-week loading plus next-week prefetch could request and
decode the same site payload twice in quick succession.

# Changes

- `DhbwAppCanteenSource` now keeps a short-lived per-site decoded payload cache.
- Failed payload fetches are evicted so later attempts can retry normally.
- JSON decoding and weekly menu parsing run through Flutter `compute` workers
  instead of doing the CPU-bound payload work on the main isolate.
- Caller-token-bound fetches no longer share an uncached in-flight request;
  successful token-bound fetches only populate the cache after completion.
- The source exposes injectable payload loading and clock hooks for focused
  tests without changing the app's production wiring.
- `CanteenPage` page-sync timer/listener retry state moved into
  `CanteenPageSyncCoordinator` so the widget keeps only page intent and UI
  behavior.

# Validation

- `flutter test test/canteen/service/dhbw_app_canteen_source_test.dart test/canteen/business/canteen_provider_refresh_policy_test.dart test/canteen/ui/canteen_page_bounds_test.dart`
