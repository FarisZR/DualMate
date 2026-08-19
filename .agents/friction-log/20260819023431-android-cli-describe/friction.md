---
title: 'Android CLI describe fails on Flutter repository root'
severity: 'minor'
---

## Expected Behavior
The Android CLI should inspect a Flutter repository when given its project root, or clearly document the supported inspection path.

## Current Behavior
The android describe --project_dir=. command fails because no gradlew exists at the Flutter repository root.

## Possible Solution
Detect Flutter projects and route inspection through Flutter tooling, or document that flutter build apk plus android run is the supported validation path.

## Minimal Reproducible Example
From the DualMate repository root, run android describe --project_dir=.

## Context
This was encountered while validating PR 118 on a connected Android device. APK deployment with flutter build apk and android run succeeded.
