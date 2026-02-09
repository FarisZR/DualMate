import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/ui/weeklyschedule/filter/filter_view_model.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

class ScheduleFilterPage extends StatelessWidget {
  final FilterViewModel _viewModel = FilterViewModel(
    KiwiContainer().resolve(),
    KiwiContainer().resolve(),
    KiwiContainer().resolve(),
    KiwiContainer().resolve(),
  );

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        try {
          await _viewModel.applyFilter();
        } catch (e, trace) {
          debugPrint('Failed to apply schedule filter: $e');
          debugPrint('$trace');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save filters'),
            ),
          );
        }
        return true;
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
              child: PropertyChangeProvider<FilterViewModel, String>(
                value: _viewModel,
                child: PropertyChangeConsumer<FilterViewModel, String>(
                    properties: const ["filterStates"],
                    builder: (BuildContext _, FilterViewModel? viewModel,
                        Set<String>? ___) {
                      if (viewModel == null) return Container();
                      return ListView.builder(
                        itemCount: viewModel.filterStates.length,
                        itemBuilder: (context, index) =>
                            FilterStateRow(viewModel.filterStates[index]),
                      );
                    }),
              ),
            )
          ],
        ),
      ),
    );
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
