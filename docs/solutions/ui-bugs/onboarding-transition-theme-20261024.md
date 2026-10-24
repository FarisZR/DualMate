---
module: Onboarding
date: 2026-10-24
problem_type: ui_bug
component: shared_axis_transition
root_cause: animation_package_theme_lookup_changed
resolution_type: code_fix
severity: high
tags: [onboarding, dark-mode, material, contrast]
---

# Onboarding transition background ignores the app theme

After upgrading to animations 3.0, `SharedAxisTransition` reads its default
background from `material_ui`'s theme. DualMate uses Flutter Material's theme,
so the transition falls back to a pale surface even when the page uses dark
foreground colors. This made the entire onboarding content nearly unreadable.

Pass the active Flutter theme's scaffold background explicitly as `fillColor`.
Pixel-level widget regressions render the actual onboarding page in light and
dark themes, before and after advancing to the next step. Both must paint the
same background as the surrounding scaffold. All seven onboarding tests pass.
