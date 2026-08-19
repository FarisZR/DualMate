---
module: Developer Experience
date: 2026-08-19
problem_type: tooling
component: android_cli
symptoms:
  - "android describe --project_dir=. fails because no gradlew exists at the Flutter repository root"
root_cause: android_describe_requires_a_gradle_project_root
resolution_type: documentation
severity: low
tags: [android-cli, flutter, validation, tooling]
issue: FarisZR/DualMate#121
---

# Android CLI validation for the Flutter repository

`android describe` inspects a Gradle project and therefore expects to find
`gradlew` in the directory passed as `--project_dir`. DualMate's repository
root is a Flutter project root; its Gradle project is under `android/`.

Use this validation sequence from the repository root:

```sh
flutter pub get
flutter build apk --debug
android describe --project_dir=android
android run --apks=build/app/outputs/flutter-apk/app-debug.apk --device=<serial>
```

The Flutter build creates the APK. `android describe` inspects the Android
subproject, and `android run` installs and launches the resulting APK on the
selected device. Passing `--project_dir=.` to `android describe` is not a
supported path for this repository.

