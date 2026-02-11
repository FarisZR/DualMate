import 'package:dualmate/common/i18n/localizations.dart';
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
  bool _isHandlingPop = false;

  @override
  void initState() {
    super.initState();
    _viewModel = FilterViewModel(
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
      KiwiContainer().resolve(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeferred();
    });
  }

  Future<void> _initializeDeferred() async {
    try {
      await Future.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      await _viewModel.initialize();
    } catch (e, trace) {
      debugPrint('Failed to initialize schedule filter page: $e');
      debugPrint('$trace');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                reverseDuration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  );
                },
                child: _isLoading
                    ? const Center(
                        key: ValueKey('filter_loading'),
                        child: CircularProgressIndicator(),
                      )
                    : PropertyChangeProvider<FilterViewModel, String>(
                        key: const ValueKey('filter_list'),
                        value: _viewModel,
                        child: PropertyChangeConsumer<FilterViewModel, String>(
                          properties: const ["filterStates"],
                          builder: (
                            BuildContext _,
                            FilterViewModel? viewModel,
                            Set<String>? ___,
                          ) {
                            if (viewModel == null) return Container();
                            return ListView.builder(
                              itemCount: viewModel.filterStates.length,
                              itemBuilder: (context, index) =>
                                  FilterStateRow(viewModel.filterStates[index]),
                            );
                          },
                        ),
                      ),
              ),
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
    return CheckboxListTile(
      value: isChecked,
      onChanged: (checked) {
        if (checked == null) return;
        setState(() {
          isChecked = checked;
          widget.filterState.isDisplayed = isChecked;
        });
      },
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(widget.filterState.entryName),
    );
  }
}
