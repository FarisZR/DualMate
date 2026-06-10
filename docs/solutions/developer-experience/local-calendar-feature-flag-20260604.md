---
title: "Local calendar access feature flag"
category: developer-experience
date: 2026-06-04
---

# Local calendar access feature flag

Local device calendar access is disabled in the default Android build. Without
the `DUALMATE_ENABLE_LOCAL_CALENDAR=true` Dart define, the app hides calendar
sync/export UI, skips foreground calendar sync startup work, and removes
`READ_CALENDAR` and `WRITE_CALENDAR` from the final merged Android manifest.

Use the default build for normal releases:

```bash
flutter build apk
```

Opt in by setting the Dart define to `true`:

```bash
flutter build apk --dart-define=DUALMATE_ENABLE_LOCAL_CALENDAR=true
```

This single compile-time flag controls both the Dart feature paths and Android
manifest permissions. The app module reads Flutter's encoded Dart defines in
Gradle and uses the manifest merger to include the calendar permissions only
when the flag is exactly `true`.
