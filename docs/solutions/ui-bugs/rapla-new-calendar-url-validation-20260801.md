---
title: Accept Rapla calendar URLs from the new Karlsruhe host
date: 2026-08-01
category: ui-bugs
tags:
  - rapla
  - schedule
  - url-validation
---

# Accept Rapla calendar URLs from the new Karlsruhe host

The new Karlsruhe Rapla host uses `/rapla/calendar` with `user` and `file`
query parameters, rather than the legacy `page=calendar` parameter. URL
validation now accepts this path-based format while continuing to accept the
legacy format.

## Verification

- `flutter test test/rapla_service_test.dart`
