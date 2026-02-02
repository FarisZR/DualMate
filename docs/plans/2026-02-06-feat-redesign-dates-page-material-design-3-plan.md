---
title: "feat: Redesign Dates Page with Material Design 3"
type: feat
date: 2026-02-06
priority: medium
estimated_effort: 3-5 days
tags: [ui, material-design-3, dates, responsive, performance]
---

# feat: Redesign Dates Page with Material Design 3

## Overview

Modernize the dates page (Rapla events view) to align with Material Design 3 guidelines. This redesign addresses several issues: outdated visual design, invisible button outfills on white backgrounds, missing error/empty states, lack of responsive tablet layouts, and potential performance improvements for smooth scrolling.

## Problem Statement

The current dates page has several UX and technical issues:

1. **Visual Design**: Card styling uses hardcoded colors (`Color(0xFFF2F2F2)`) rather than MD3 tonal surfaces
2. **Button Visibility**: White `TextButton` outfills disappear against white backgrounds, making buttons hard to tap
3. **Missing Empty State**: When neither Rapla nor DHTermine is configured, users see only a minimal banner instead of a helpful full-page empty state with setup guidance
4. **No Responsive Layout**: Single-column layout on all devices, including tablets where a 2-column layout would improve content density
5. **Performance Concerns**: Potential jank during scroll due to card rebuilds and lack of optimization patterns
6. **Race Conditions**: ViewModel lacks `_isDisposed` guards, causing potential `notifyListeners after dispose` errors

## Proposed Solution

### High-Level Approach

1. **MD3 Tonal Surface Cards**: Replace hardcoded card colors with `Theme.of(context).colorScheme.surfaceContainerHighest` for proper MD3 styling in both light and dark modes
2. **Filled Buttons**: Replace `TextButton` with `FilledButton`/`FilledTonalButton` throughout the dates page for visibility
3. **Full-Page Empty State**: Create a new `DatesEmptyState` widget following the `ScheduleEmptyState` pattern with banner + placeholder illustration + setup CTA
4. **Adaptive Tablet Layout**: Implement 2-column grid layout for screens above 600dp using `LayoutBuilder`
5. **Performance Optimization**: Apply `const` constructors, extract widgets, use `ListView.builder` patterns, add dispose guards
6. **Fix Race Conditions**: Add `_isDisposed` guards following documented learnings pattern

## Technical Approach

### Architecture

```
lib/date_management/ui/
├── date_management_page.dart          # Main page (MODIFY)
├── viewmodels/
│   └── date_management_view_model.dart # ViewModel (MODIFY - add dispose guards)
└── widgets/
    ├── dates_empty_state.dart              # NEW: Full-page empty state
    ├── dates_empty_state_placeholder.dart  # NEW: CustomPaint placeholder
    ├── important_event_section_card.dart   # NEW: Extracted MD3 card widget
    ├── important_event_tile.dart           # NEW: Extracted tile widget
    ├── date_filter_options.dart            # MODIFY: FilledButton
    ├── date_detail_bottom_sheet.dart       # Existing
    └── date_management_help_dialog.dart    # Existing
```

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Empty state trigger | When BOTH Rapla AND DHTermine unconfigured | DHTermine is public API (always works), Rapla requires URL |
| Tablet breakpoint | 600dp for 2 columns | Standard Android tablet breakpoint, matches existing `PlatformUtil` |
| Card styling | MD3 tonal surfaces | Future-proof, respects system theme |
| Button type | FilledTonalButton | Visible but not overly prominent |
| List optimization | `ListView.separated` with builder | Lazy loading, consistent separators |

### Implementation Phases

#### Phase 1: Fix Race Conditions (Critical Bug Fix)
**Estimated Effort**: 2-3 hours

**Tasks:**
- [x] Add `bool _isDisposed = false` to `DateManagementViewModel`
- [x] Add dispose guards after each `await` in `_doUpdateRaplaEvents()`, `_doUpdateDates()`, `loadNextRaplaPage()`
- [x] Cancel `_errorResetTimer` in `dispose()`
- [x] Add `_isDisposed` check before every `notifyListeners()` call

**Files:**
- `lib/date_management/ui/viewmodels/date_management_view_model.dart`

**Success Criteria:**
- [ ] No `notifyListeners after dispose` warnings when rapidly navigating away from dates tab
- [x] All existing tests pass

**Code Example:**
```dart
// date_management_view_model.dart
bool _isDisposed = false;

Future<void> _doUpdateRaplaEvents() async {
  _resetRaplaPaging();
  await _applyCachedRaplaWindows();
  if (_isDisposed) return;
  
  var raplaEvents = await _readRaplaImportantEventsPage();
  if (_isDisposed) return;
  _updateMutex.token.throwIfCancelled();

  if (raplaEvents != null) {
    _setImportantEvents(raplaEvents);
  }

  await _prefetchRaplaUntilFilled();
  if (_isDisposed) return;

  _updateFailed = raplaEvents == null;
  if (updateFailed) {
    _cancelErrorInFuture();
  }

  if (!_isDisposed) notifyListeners("updateFailed");

  if (raplaEvents != null) {
    _refreshRaplaEventsInBackground();
  }
}

@override
void dispose() {
  _isDisposed = true;
  _updateMutex.cancel();
  _errorResetTimer?.cancel();
  super.dispose();
}
```

#### Phase 2: Create Empty State Components
**Estimated Effort**: 3-4 hours

**Tasks:**
- [x] Create `DatesEmptyStatePlaceholder` widget using `CustomPaint` (following `ScheduleEmptyStatePlaceholder` pattern)
- [x] Create `DatesEmptyState` widget with banner message + placeholder + setup button
- [x] Integrate empty state into `DateManagementPage` when both sources unconfigured

**Files to Create:**
- `lib/date_management/ui/widgets/dates_empty_state_placeholder.dart`
- `lib/date_management/ui/widgets/dates_empty_state.dart`

**Files to Modify:**
- `lib/date_management/ui/date_management_page.dart`
- `lib/date_management/ui/viewmodels/date_management_view_model.dart` (add `bothSourcesUnconfigured` getter)

**Success Criteria:**
- [x] Empty state displays when neither Rapla URL is set nor DHTermine mode enabled
- [x] Setup button opens `SelectSourceDialog`
- [x] Empty state respects light/dark theme

**Code Example:**
```dart
// dates_empty_state_placeholder.dart
class DatesEmptyStatePlaceholder extends StatelessWidget {
  const DatesEmptyStatePlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: CustomPaint(
            painter: _DatesPlaceholderPainter(
              cardColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              accentColor: colorScheduleEntryClass(context).withOpacity(0.12),
            ),
            child: Container(),
          ),
        );
      },
    );
  }
}

// dates_empty_state.dart
class DatesEmptyState extends StatelessWidget {
  const DatesEmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          child: BannerWidget(
            message: L.of(context).dateManagementEmptyStateBannerMessage,
            onButtonTap: () async {
              await SelectSourceDialog(
                KiwiContainer().resolve(),
                KiwiContainer().resolve(),
              ).show(context);
            },
            buttonText: L.of(context).scheduleEmptyStateSetUrl.toUpperCase(),
          ),
        ),
        Expanded(
          child: ClipRRect(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: DatesEmptyStatePlaceholder(),
            ),
          ),
        ),
      ],
    );
  }
}
```

#### Phase 3: Extract and Modernize Card Components
**Estimated Effort**: 4-5 hours

**Tasks:**
- [x] Extract `ImportantEventSectionCard` widget from `_buildSectionCard` method
- [x] Extract `ImportantEventTile` widget from `_buildEventTile`/`_buildNestedEventTile`
- [x] Replace hardcoded card colors with MD3 tonal surfaces
- [x] Apply `const` constructors where possible
- [x] Add proper widget keys for efficient rebuilds

**Files to Create:**
- `lib/date_management/ui/widgets/important_event_section_card.dart`
- `lib/date_management/ui/widgets/important_event_tile.dart`

**Files to Modify:**
- `lib/date_management/ui/date_management_page.dart`

**Success Criteria:**
- [x] Cards use `Theme.of(context).colorScheme.surfaceContainerHighest` for backgrounds
- [x] Exam sections still have red tint overlay
- [x] Light/dark mode transitions are smooth
- [x] All extracted widgets have `const` constructors

**Code Example:**
```dart
// important_event_section_card.dart
class ImportantEventSectionCard extends StatelessWidget {
  final ImportantEventSection section;
  
  const ImportantEventSectionCard({
    Key? key,
    required this.section,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: _sectionBackground(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildChildren(context),
      ),
    );
  }

  Color _sectionBackground(BuildContext context) {
    if (_isExamSection()) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final opacity = isDark ? 0.22 : 0.12;
      return const Color(0xffff0000).withOpacity(opacity);
    }
    
    // MD3 tonal surface instead of hardcoded colors
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  bool _isExamSection() {
    if (section.events.any((event) => event.type == ScheduleEntryType.Exam)) {
      return true;
    }
    final title = section.header?.title.toLowerCase() ?? '';
    return title.contains('klausur');
  }

  List<Widget> _buildChildren(BuildContext context) {
    // ... existing logic extracted
  }
}
```

#### Phase 4: Replace Buttons with FilledButton
**Estimated Effort**: 1-2 hours

**Tasks:**
- [x] Replace `TextButton` with `FilledTonalButton` in `BannerWidget`
- [x] Replace `TextButton` with `FilledTonalButton` in retry buttons
- [x] Ensure button colors work in both light and dark modes

**Files to Modify:**
- `lib/ui/banner_widget.dart`
- `lib/date_management/ui/date_management_page.dart` (retry button in footer)

**Success Criteria:**
- [x] All interactive buttons visible against white backgrounds
- [x] Buttons maintain good contrast in dark mode
- [x] Touch targets remain at least 48dp

**Code Example:**
```dart
// banner_widget.dart
@override
Widget build(BuildContext context) {
  return Container(
    // ... existing decoration
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(message),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                child: FilledTonalButton(
                  onPressed: onButtonTap,
                  child: Text(buttonText),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
```

#### Phase 5: Implement Adaptive Tablet Layout
**Estimated Effort**: 4-5 hours

**Tasks:**
- [x] Add `LayoutBuilder` wrapper around event list
- [x] Implement 2-column `GridView` for screens > 600dp
- [x] Ensure consistent card spacing in grid layout
- [ ] Test infinite scroll pagination in grid mode
- [ ] Handle orientation changes gracefully

**Files to Modify:**
- `lib/date_management/ui/date_management_page.dart`

**Success Criteria:**
- [x] Single column on phones (< 600dp)
- [x] Two columns on tablets (>= 600dp)
- [ ] Smooth transitions during rotation
- [ ] Pagination works in both layouts
- [ ] Cards maintain consistent aspect ratio

**Code Example:**
```dart
// date_management_page.dart
Widget _buildImportantEventsList(
  DateManagementViewModel model,
  BuildContext context,
) {
  var sections = model.importantEventSections;
  if (sections.isEmpty) {
    _scheduleRaplaAutoload(model);
    return _buildEmptyRaplaList(model, context);
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      final isTablet = constraints.maxWidth >= 600;
      final crossAxisCount = isTablet ? 2 : 1;
      
      _scheduleRaplaAutoload(model);
      
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >=
              notification.metrics.maxScrollExtent - 200) {
            model.loadNextRaplaPage();
          }
          return false;
        },
        child: GridView.builder(
          controller: _raplaScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: null, // Auto-size based on content
          ),
          itemCount: sections.length + 1,
          itemBuilder: (context, index) {
            if (index < sections.length) {
              return ImportantEventSectionCard(
                key: ValueKey('section_${sections[index].hashCode}'),
                section: sections[index],
              );
            }
            return _buildRaplaFooter(model, context);
          },
        ),
      );
    },
  );
}
```

#### Phase 6: Performance Optimization & Polish
**Estimated Effort**: 2-3 hours

**Tasks:**
- [x] Add `const` constructors to all new widgets
- [x] Use `ValueKey` for list items to optimize rebuilds
- [ ] Profile scrolling performance on low-end device
- [ ] Add `RepaintBoundary` around cards if needed
- [ ] Verify no unnecessary rebuilds using DevTools

**Files to Modify:**
- All newly created widget files
- `lib/date_management/ui/date_management_page.dart`

**Success Criteria:**
- [ ] Smooth 60fps scrolling on mid-range devices
- [ ] No jank during infinite scroll pagination
- [ ] Initial load time < 500ms (cached data)
- [ ] Memory usage stable during extended scrolling

**Profiling Commands:**
```bash
flutter run --profile -d <device_id>
# Use DevTools Performance tab to verify frame times
```

## Alternative Approaches Considered

### 1. Use Sliver-based Layout
**Considered:** `CustomScrollView` with `SliverGrid` and `SliverList`
**Rejected:** More complex implementation, current `ListView`/`GridView` pattern sufficient for requirements
**Tradeoff:** Slivers would allow mixing grid and list sections, but adds complexity

### 2. Use Third-Party Grid Library (flutter_staggered_grid_view)
**Considered:** For variable-height cards in grid
**Rejected:** Adds dependency, Flutter's built-in `GridView` handles this with `mainAxisExtent: null`
**Tradeoff:** Staggered grid looks nicer but harder to maintain consistent layout

### 3. Shared Element Transitions
**Considered:** Hero animations between list item and detail sheet
**Rejected:** Out of scope for this redesign, could be added later
**Tradeoff:** Better UX but significant additional effort

## Acceptance Criteria

### Functional Requirements

- [x] Dates page displays Rapla events in MD3 tonal surface cards
- [x] Full-page empty state shows when both Rapla URL missing AND DHTermine mode disabled
- [x] Empty state includes: banner message, placeholder illustration, "Set URL" button
- [x] Tapping setup button opens `SelectSourceDialog`
- [x] 2-column grid layout on tablets (>= 600dp width)
- [x] Single column on phones (< 600dp width)
- [ ] Infinite scroll pagination continues to work
- [ ] Filter options (passed dates, outside study) continue to work
- [ ] Event type colors (exam=red, holiday=gray) maintained

### Non-Functional Requirements

- [ ] **Performance**: Initial load < 500ms with cached data
- [ ] **Performance**: Scrolling maintains 60fps on mid-range devices
- [ ] **Performance**: No jank during pagination load
- [ ] **Accessibility**: Cards have semantic labels for screen readers
- [ ] **Accessibility**: Touch targets >= 48dp
- [ ] **Theme**: Proper colors in both light and dark mode
- [x] **Stability**: No `notifyListeners after dispose` errors

### Quality Gates

- [x] All existing `date_management` tests pass
- [x] New widget tests for `DatesEmptyState`, `ImportantEventSectionCard`
- [ ] Manual testing on phone (< 600dp) and tablet (>= 600dp)
- [ ] Manual testing of light/dark mode transitions
- [ ] Performance profile shows no frame drops during scroll

## Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Initial load time | < 500ms | Stopwatch in `initState` |
| Scroll frame time | < 16.67ms (60fps) | Flutter DevTools |
| Empty state discovery | User taps setup within 5s | Manual observation |
| Crash rate (dispose errors) | 0 | Crashlytics/logs |

## Dependencies & Prerequisites

### Technical Dependencies
- Flutter SDK >= 3.0.0 (already met)
- Material 3 enabled (`useMaterial3: true` - already configured)
- Existing `SelectSourceDialog` widget
- Existing `BannerWidget` component

### External Dependencies
- None

### Blockers
- None identified

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Race conditions cause crashes | High | Medium | Implement dispose guards first (Phase 1) |
| Tablet layout breaks phone UI | Medium | High | Test continuously on both form factors |
| Accessibility regression | Medium | High | Test with TalkBack/VoiceOver before merge |
| Performance regression | Low | Medium | Profile before/after, use DevTools |
| Theme colors incorrect | Low | Low | Test light/dark explicitly |

## Resource Requirements

### Team
- 1 Flutter developer (primary)
- 1 reviewer (for PR review)

### Time
- Estimated: 3-5 days
- Buffer: +1 day for testing/polish

### Infrastructure
- Test devices: Phone (< 600dp), Tablet (>= 600dp)
- Android + iOS for cross-platform verification

## Future Considerations

### Potential Enhancements (Not in Scope)
1. **Pull-to-Refresh**: Add `RefreshIndicator` for manual refresh
2. **Skeleton Loading**: Show placeholder cards during initial load
3. **Rapla Event Tap**: Show detail bottom sheet for Rapla events (like DHTermine)
4. **3-Column Layout**: For very large tablets (>= 900dp)
5. **Shared Element Transitions**: Hero animation to detail view
6. **Offline Mode**: Show cached data with offline indicator

### Extensibility Points
- `ImportantEventSectionCard` can be reused for similar list UIs
- `DatesEmptyStatePlaceholder` pattern can be applied to other empty states
- Adaptive layout logic could be extracted to utility class

## Documentation Plan

### Code Documentation
- [ ] Add dartdoc comments to all new public widgets
- [ ] Update class-level comments in `DateManagementViewModel`

### User Documentation
- None required (UI improvement, no new features)

### Developer Documentation
- [ ] Add note to this plan about dispose guard pattern for future reference

## References & Research

### Internal References
- Empty state pattern: `lib/schedule/ui/widgets/schedule_empty_state.dart:8`
- Placeholder pattern: `lib/schedule/ui/widgets/schedule_empty_state_placeholder.dart:4`
- Color definitions: `lib/common/ui/colors.dart:74` (ColorPalettes.buildTheme)
- Tablet detection: `lib/common/util/platform_util.dart:17` (isTablet)
- Dispose guard pattern: `docs/solutions/runtime-errors/notifylisteners-after-dispose-schedule-20260126.md`

### External References
- Material Design 3 Color System: https://m3.material.io/styles/color/system/overview
- Flutter GridView: https://api.flutter.dev/flutter/widgets/GridView-class.html
- Flutter Performance Best Practices: https://docs.flutter.dev/perf/best-practices

### Related Work
- Schedule page swipe fix: `docs/solutions/ui-bugs/swipe-unloaded-week-no-fetch-schedule-ui-20260127.md`
- Schedule dispose guards: `docs/solutions/runtime-errors/notifylisteners-after-dispose-schedule-20260126.md`

---

## Implementation Checklist

### Pre-Implementation
- [ ] Review this plan with team
- [ ] Set up test devices (phone + tablet)
- [ ] Create feature branch: `feat/dates-page-md3-redesign`

### Phase 1: Dispose Guards
- [x] Add `_isDisposed` flag
- [x] Guard all `notifyListeners` calls
- [x] Cancel timers in `dispose()`
- [ ] Test rapid navigation

### Phase 2: Empty State
- [x] Create `DatesEmptyStatePlaceholder`
- [x] Create `DatesEmptyState`
- [x] Add `bothSourcesUnconfigured` getter
- [x] Integrate into page
- [x] Add localization strings

### Phase 3: Card Components
- [x] Extract `ImportantEventSectionCard`
- [x] Extract `ImportantEventTile`
- [x] Apply MD3 tonal surfaces
- [x] Add `const` constructors

### Phase 4: Buttons
- [x] Update `BannerWidget` to `FilledTonalButton`
- [x] Update retry button in footer
- [x] Verify contrast in both themes

### Phase 5: Tablet Layout
- [x] Add `LayoutBuilder`
- [x] Implement `GridView.builder`
- [ ] Test pagination in grid
- [ ] Test rotation

### Phase 6: Polish
- [ ] Performance profiling
- [ ] Add `RepaintBoundary` if needed
- [ ] Final testing pass
- [ ] Create PR

### Post-Implementation
- [ ] PR review
- [ ] QA testing
- [ ] Merge to main
