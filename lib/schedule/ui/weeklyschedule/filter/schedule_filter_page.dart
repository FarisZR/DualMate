import 'dart:async';

import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class ScheduleFilterPage extends StatefulWidget {
  final Future<void>? preloadFuture;
  final ClassReminderController? reminderController;

  const ScheduleFilterPage({
    super.key,
    this.preloadFuture,
    this.reminderController,
  });

  @override
  State<ScheduleFilterPage> createState() => _ScheduleFilterPageState();
}

class _ScheduleFilterPageState extends State<ScheduleFilterPage> {
  late final FilterViewModel _viewModel;
  bool _isLoading = !FilterViewModel.hasCachedStates;
  bool _showLoadedList = FilterViewModel.hasCachedStates;
  bool _hasInitError = false;
  bool _isHandlingPop = false;
  bool _didInitializeViewModel = false;
  ClassReminderController? _reminderController;
  Future<void>? _pendingDisplayChange;

  @override
  void initState() {
    super.initState();
    _viewModel = FilterViewModel(
      KiwiContainer().resolve<ScheduleEntryRepository>(),
      KiwiContainer().resolve<ScheduleFilterRepository>(),
    );
    _reminderController = widget.reminderController;
    final container = KiwiContainer();
    if (_reminderController == null &&
        container.isRegistered<ClassReminderController>()) {
      _reminderController = container.resolve<ClassReminderController>();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeferred();
    });
  }

  Future<void> _initializeDeferred() async {
    var initSucceeded = false;
    try {
      await widget.preloadFuture;
      if (!mounted) return;
      await _viewModel.initialize();
      _didInitializeViewModel = _viewModel.isInitialized;
      initSucceeded = true;
    } catch (e, trace) {
      debugPrint('Failed to initialize schedule filter page: $e');
      debugPrint('$trace');
      if (!mounted) return;
      setState(() {
        _hasInitError = true;
      });
    } finally {
      if (!mounted) return;
      if (!initSucceeded) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
        _showLoadedList = true;
      });
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handlePopRequested(context);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          actionsIconTheme: Theme.of(context).iconTheme,
          elevation: 0,
          iconTheme: Theme.of(context).iconTheme,
          title: Text(L.of(context).filterTitle),
          toolbarTextStyle: Theme.of(context).textTheme.bodyMedium,
          titleTextStyle: Theme.of(context).textTheme.titleLarge,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(L.of(context).filterDescription),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                L.of(context).filterDisplayedClasses,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _hasInitError
                  ? _buildInitErrorState(context)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        PropertyChangeProvider<FilterViewModel, String>(
                          value: _viewModel,
                          child:
                              PropertyChangeConsumer<FilterViewModel, String>(
                                properties: const ["filterStates"],
                                builder:
                                    (
                                      BuildContext _,
                                      FilterViewModel? viewModel,
                                      Set<String>? ___,
                                    ) {
                                      if (viewModel == null) return Container();
                                      Widget buildList() => AnimatedSlide(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        offset: _showLoadedList
                                            ? Offset.zero
                                            : const Offset(0, 0.03),
                                        child: AnimatedOpacity(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          opacity: _showLoadedList ? 1 : 0,
                                          child: ListView.builder(
                                            itemCount:
                                                viewModel.filterStates.length,
                                            itemExtent: 56,
                                            scrollCacheExtent:
                                                const ScrollCacheExtent.pixels(
                                                  320,
                                                ),
                                            itemBuilder: (context, index) {
                                              final state =
                                                  viewModel.filterStates[index];
                                              return FilterStateRow(
                                                state,
                                                hasReminder:
                                                    _reminderController
                                                        ?.hasReminderForTitle(
                                                          state.entryName,
                                                        ) ??
                                                    false,
                                                onDisplayChanged: (displayed) =>
                                                    _handleDisplayChange(
                                                      state,
                                                      displayed,
                                                    ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                      final reminders = _reminderController;
                                      if (reminders == null) return buildList();
                                      return AnimatedBuilder(
                                        animation: reminders,
                                        builder: (_, __) => buildList(),
                                      );
                                    },
                              ),
                        ),
                        if (!_showLoadedList)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(L.of(context).filterLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasInitError = false;
                  _showLoadedList = false;
                });
                _initializeDeferred();
              },
              child: Text(L.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePopRequested(BuildContext context) async {
    if (_isHandlingPop) return;
    _isHandlingPop = true;
    var didChangeFilters = false;
    var applySucceeded = false;
    try {
      if (!_didInitializeViewModel || _hasInitError) {
        return;
      }
      await _pendingDisplayChange;
      didChangeFilters = await _viewModel.applyFilter();
      applySucceeded = true;
    } on FilterValidationException catch (e, trace) {
      debugPrint('Failed to validate schedule filter: $e');
      debugPrint('$trace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).filterSaveError)));
    } on FilterSaveException catch (e, trace) {
      debugPrint('Failed to persist schedule filter: $e');
      debugPrint('$trace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).filterSaveError)));
    } catch (e, trace) {
      debugPrint('Failed to apply schedule filter: $e');
      debugPrint('$trace');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).filterSaveError)));
    } finally {
      if (applySucceeded && mounted) {
        Navigator.of(context).pop(didChangeFilters);
      }
      _isHandlingPop = false;
    }
  }

  Future<bool> _handleDisplayChange(
    ScheduleEntryFilterState state,
    bool displayed,
  ) {
    final future = _doDisplayChange(state, displayed);
    if (!displayed) {
      _pendingDisplayChange = future.then((_) {}).catchError((_) {});
    }
    return future;
  }

  Future<bool> _doDisplayChange(
    ScheduleEntryFilterState state,
    bool displayed,
  ) async {
    final reminders = _reminderController;
    if (displayed ||
        reminders == null ||
        !reminders.hasReminderForTitle(state.entryName)) {
      return true;
    }

    final strings = L.of(context);
    final choice = await showDialog<_HiddenReminderChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          strings.filterReminderHideTitle.replaceAll(
            '{className}',
            state.entryName,
          ),
        ),
        content: Text(strings.filterReminderHideMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.classReminderPermissionCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_HiddenReminderChoice.keep),
            child: Text(strings.filterReminderKeep),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_HiddenReminderChoice.remove),
            child: Text(strings.filterReminderRemove),
          ),
        ],
      ),
    );

    if (choice == null) return false;
    if (choice == _HiddenReminderChoice.remove) {
      try {
        await reminders.removeRemindersForTitle(state.entryName);
        // Update the model even if the row widget is already disposed.
        state.isDisplayed = false;
      } catch (error, trace) {
        debugPrint('Failed to remove reminders for hidden class: $error');
        debugPrint('$trace');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(strings.filterSaveError)));
        }
        return false;
      }
    }
    return true;
  }
}

enum _HiddenReminderChoice { keep, remove }

class FilterStateRow extends StatefulWidget {
  final ScheduleEntryFilterState filterState;
  final bool hasReminder;
  final Future<bool> Function(bool displayed)? onDisplayChanged;

  FilterStateRow(
    this.filterState, {
    this.hasReminder = false,
    this.onDisplayChanged,
  }) : super(key: ValueKey(filterState.entryName));

  @override
  _FilterStateRowState createState() => _FilterStateRowState();
}

class _FilterStateRowState extends State<FilterStateRow> {
  bool isChecked = false;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();

    isChecked = widget.filterState.isDisplayed;
  }

  @override
  void didUpdateWidget(covariant FilterStateRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterState.isDisplayed != widget.filterState.isDisplayed) {
      setState(() {
        isChecked = widget.filterState.isDisplayed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => unawaited(_setChecked(!isChecked)),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: (checked) {
                if (checked != null) unawaited(_setChecked(checked));
              },
            ),
            Expanded(
              child: Text(
                widget.filterState.entryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.hasReminder)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.notifications,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _setChecked(bool checked) async {
    if (checked == isChecked || _isChanging) return;
    _isChanging = true;
    try {
      final accepted = await widget.onDisplayChanged?.call(checked) ?? true;
      if (!accepted || !mounted) return;
      setState(() {
        isChecked = checked;
        widget.filterState.isDisplayed = checked;
      });
    } finally {
      _isChanging = false;
    }
  }
}
