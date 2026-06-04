---
title: "Local calendar access feature flag"
category: developer-experience
date: 2026-06-04
---

# Local calendar access feature flag

Local device calendar access is disabled in the default Android build. The
standard flavor hides calendar sync/export UI, skips foreground calendar sync
startup work, and does not request `READ_CALENDAR` or `WRITE_CALENDAR`.

Use the standard flavor for normal releases:

```bash
flutter build apk --flavor standard
```

Use the local-calendar flavor and Dart define together to opt in:

```bash
flutter build apk \
  --flavor localCalendar \
  --dart-define=DUALMATE_ENABLE_LOCAL_CALENDAR=true
```

Both switches are intentional. The flavor controls Android manifest
permissions, while the Dart define controls Flutter UI and background sync
paths.
