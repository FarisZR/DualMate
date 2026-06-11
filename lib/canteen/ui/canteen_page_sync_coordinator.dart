import 'dart:async';

import 'package:dualmate/common/util/date_utils.dart';
import 'package:flutter/material.dart';

const Duration kCanteenDeferredPageSyncRetryDelay = Duration(milliseconds: 360);

bool shouldDeferCanteenPageSync({
  required bool hasClients,
  required int attachedPositions,
  required bool isScrolling,
  required bool hasPendingPageDelta,
}) {
  if (!hasClients) {
    return true;
  }

  if (attachedPositions != 1) {
    return true;
  }

  if (hasPendingPageDelta) {
    return true;
  }

  return isScrolling;
}

DateTime resolveCanteenPageSyncTarget({
  required DateTime baseDate,
  required List<DateTime> visibleDays,
  DateTime? selectedDate,
  double? currentPage,
}) {
  if (visibleDays.isNotEmpty && currentPage != null) {
    final roundedPage = currentPage.round().clamp(0, visibleDays.length - 1);
    final controllerTarget = visibleDays[roundedPage];
    final selectedIsFallback =
        selectedDate == null || isAtSameDay(selectedDate, baseDate);
    if (selectedIsFallback && !isAtSameDay(controllerTarget, baseDate)) {
      return controllerTarget;
    }
  }

  return selectedDate ?? baseDate;
}

bool hasPendingCommittedCanteenPage({
  required int committedPage,
  double? currentPage,
}) {
  if (currentPage == null) {
    return false;
  }

  return (currentPage - committedPage).abs() > 0.01;
}

class CanteenPageSyncCoordinator {
  final PageController pageController;
  final ValueNotifier<int> pageNotifier;
  final bool Function() isMounted;
  final VoidCallback onRetryPendingSync;
  Timer? _deferredPageSyncTimer;
  bool _pageSyncPending = false;
  bool _pageScrollListenerAttached = false;

  CanteenPageSyncCoordinator({
    required this.pageController,
    required this.pageNotifier,
    required this.isMounted,
    required this.onRetryPendingSync,
  });

  void markPending() {
    _pageSyncPending = true;
  }

  void clearPending() {
    _pageSyncPending = false;
  }

  bool shouldDeferSync() {
    final hasClients = pageController.hasClients;
    final attachedPositions = pageController.positions.length;
    final currentPage = hasClients && attachedPositions == 1
        ? pageController.page
        : null;
    final hasPendingPageDelta = hasPendingCommittedCanteenPage(
      committedPage: pageNotifier.value,
      currentPage: currentPage,
    );
    final isScrolling = hasClients && attachedPositions == 1
        ? pageController.position.isScrollingNotifier.value
        : false;

    if (!hasClients || attachedPositions != 1) {
      _scheduleDeferredRetry();
      return true;
    }

    _attachPageScrollListener();

    if (shouldDeferCanteenPageSync(
      hasClients: hasClients,
      attachedPositions: attachedPositions,
      isScrolling: isScrolling,
      hasPendingPageDelta: hasPendingPageDelta,
    )) {
      if (hasPendingPageDelta) {
        _scheduleDeferredRetry();
      }
      return true;
    }

    return false;
  }

  void retryPendingSync() {
    if (!_pageSyncPending || !isMounted()) {
      return;
    }

    onRetryPendingSync();
  }

  void dispose() {
    _deferredPageSyncTimer?.cancel();
    _detachPageScrollListener();
  }

  void _scheduleDeferredRetry() {
    _deferredPageSyncTimer?.cancel();
    _deferredPageSyncTimer = Timer(kCanteenDeferredPageSyncRetryDelay, () {
      retryPendingSync();
    });
  }

  void _attachPageScrollListener() {
    if (_pageScrollListenerAttached || !pageController.hasClients) {
      return;
    }

    if (pageController.positions.length != 1) {
      return;
    }

    pageController.position.isScrollingNotifier.addListener(
      _handlePageScrollStateChanged,
    );
    _pageScrollListenerAttached = true;
  }

  void _detachPageScrollListener() {
    if (!_pageScrollListenerAttached || !pageController.hasClients) {
      _pageScrollListenerAttached = false;
      return;
    }

    if (pageController.positions.length == 1) {
      pageController.position.isScrollingNotifier.removeListener(
        _handlePageScrollStateChanged,
      );
    }

    _pageScrollListenerAttached = false;
  }

  void _handlePageScrollStateChanged() {
    if (!isMounted() || !pageController.hasClients) {
      return;
    }

    if (pageController.positions.length != 1) {
      _detachPageScrollListener();
      _scheduleDeferredRetry();
      return;
    }

    if (pageController.position.isScrollingNotifier.value) {
      return;
    }

    retryPendingSync();
  }
}
