import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/business/schedule_provider.dart';
import 'package:dualmate/schedule/business/schedule_source_provider.dart';
import 'package:dualmate/schedule/data/schedule_entry_repository.dart';
import 'package:dualmate/schedule/data/schedule_filter_repository.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class ScheduleFilterPage extends StatefulWidget {
  const ScheduleFilterPage({super.key});

  @override
  State<ScheduleFilterPage> createState() => _ScheduleFilterPageState();
}

class _ScheduleFilterPageState extends State<ScheduleFilterPage> {
  late final FilterViewModel _viewModel;
  bool _isLoading = true;
  bool _showLoadedList = false;
  bool _hasInitError = false;
  bool _isHandlingPop = false;

  @override
  void initState() {
    super.initState();
    _viewModel = FilterViewModel(
      KiwiContainer().resolve<ScheduleEntryRepository>(),
      KiwiContainer().resolve<ScheduleFilterRepository>(),
      KiwiContainer().resolve<ScheduleSourceProvider>(),
      KiwiContainer().resolve<ScheduleProvider>(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeferred();
    });
  }

  Future<void> _initializeDeferred() async {
    var initSucceeded = false;
    try {
      await Future.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      await _viewModel.initialize();
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
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _showLoadedList = true;
        });
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
                              child: PropertyChangeConsumer<FilterViewModel,
                                  String>(
                                properties: const ["filterStates"],
                                builder: (
                                  BuildContext _,
                                  FilterViewModel? viewModel,
                                  Set<String>? ___,
                                ) {
                                  if (viewModel == null) return Container();
                                  return AnimatedSlide(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    offset: _showLoadedList
                                        ? Offset.zero
                                        : const Offset(0, 0.03),
                                    child: AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                      opacity: _showLoadedList ? 1 : 0,
                                      child: ListView.builder(
                                        itemCount:
                                            viewModel.filterStates.length,
                                        itemExtent: 56,
                                        cacheExtent: 320,
                                        itemBuilder: (context, index) =>
                                            FilterStateRow(
                                                viewModel.filterStates[index]),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (!_showLoadedList)
                              const Center(
                                child: CircularProgressIndicator(),
                              ),
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
            Text(
              L.of(context).filterSaveError,
              textAlign: TextAlign.center,
            ),
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
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePopRequested(BuildContext context) async {
    if (_isHandlingPop) return;
    _isHandlingPop = true;
    try {
      await _viewModel.applyFilter();
    } on FilterValidationException catch (e, trace) {
      debugPrint('Failed to validate schedule filter: $e');
      debugPrint('$trace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.of(context).filterSaveError),
        ),
      );
    } on FilterSaveException catch (e, trace) {
      debugPrint('Failed to persist schedule filter: $e');
      debugPrint('$trace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.of(context).filterSaveError),
        ),
      );
    } catch (e, trace) {
      debugPrint('Failed to apply schedule filter: $e');
      debugPrint('$trace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.of(context).filterSaveError),
        ),
      );
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
      _isHandlingPop = false;
    }
  }
}

class FilterStateRow extends StatefulWidget {
  final ScheduleEntryFilterState filterState;

  FilterStateRow(this.filterState)
      : super(key: ValueKey(filterState.entryName));

  @override
  _FilterStateRowState createState() => _FilterStateRowState();
}

class _FilterStateRowState extends State<FilterStateRow> {
  bool isChecked = false;

  @override
  void initState() {
    super.initState();

    isChecked = widget.filterState.isDisplayed;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          isChecked = !isChecked;
          widget.filterState.isDisplayed = isChecked;
        });
      },
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Checkbox(
              value: isChecked,
              onChanged: (checked) {
                if (checked == null) return;
                setState(() {
                  isChecked = checked;
                  widget.filterState.isDisplayed = isChecked;
                });
              },
            ),
            Expanded(
              child: Text(
                widget.filterState.entryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
