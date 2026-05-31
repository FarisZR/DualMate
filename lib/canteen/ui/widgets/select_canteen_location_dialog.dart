import 'package:dualmate/canteen/business/canteen_location_service.dart';
import 'package:dualmate/canteen/model/canteen_location.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:flutter/material.dart';

class SelectCanteenLocationDialog {
  final CanteenLocationService _locationService;

  SelectCanteenLocationDialog(this._locationService);

  Future<void> show(BuildContext context) async {
    final selected = await _locationService.getSelectedLocation();
    var current = selected;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(L.of(context).onboardingCanteenLocationTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        L.of(context).onboardingCanteenLocationDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    RadioGroup<CanteenLocation>(
                      groupValue: current,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          current = value;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _locationService.supportedLocations().map(
                          (location) {
                            return RadioListTile<CanteenLocation>(
                              value: location,
                              title: Text(location.name),
                              subtitle: location.subtitle == null
                                  ? null
                                  : Text(location.subtitle!),
                            );
                          },
                        ).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(L.of(context).dialogCancel),
                ),
                TextButton(
                  onPressed: () async {
                    await _locationService.setSelectedLocation(current);
                    if (context.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(L.of(context).dialogOk),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
