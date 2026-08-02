---
title: "Repackage localrelease APK after branch switches"
category: developer-experience
date: 2026-08-02
---

# Repackage localrelease APK after branch switches

Switching branches could leave `build/app/outputs/flutter-apk/app-localrelease-release.apk`
from the previously checked-out branch. Flutter regenerated the current
`app.so`, but AGP treated the local release native-library merge and packaging
tasks as up to date because their paths and filenames did not change.

The app module now forces these local release tasks to run:

- `mergeLocalreleaseReleaseJniLibFolders`
- `mergeLocalreleaseReleaseNativeLibs`
- `packageLocalreleaseRelease`

This preserves Flutter's incremental Dart compilation while ensuring the final
APK is repackaged from the current checkout:

```bash
flutter build apk --release --flavor localrelease
```

A full `flutter clean` is still useful when generated platform tooling is
stale, but it is no longer required solely after switching branches.
