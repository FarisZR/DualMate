import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/schedule/reminders/class_reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReminderConfigurationSheet extends StatefulWidget {
  final ClassReminderRule? existingRule;
  final Future<void> Function(Duration offset, ClassReminderScope scope) onSave;
  final Future<void> Function()? onRemove;

  const ReminderConfigurationSheet({
    super.key,
    required this.existingRule,
    required this.onSave,
    this.onRemove,
  });

  @override
  State<ReminderConfigurationSheet> createState() =>
      _ReminderConfigurationSheetState();
}

class _ReminderConfigurationSheetState
    extends State<ReminderConfigurationSheet> {
  static const _presetMinutes = [5, 15, 30, 60];
  late int _minutes;
  late ClassReminderScope _scope;
  late bool _custom;
  late final TextEditingController _customController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _minutes = widget.existingRule?.offset.inMinutes ?? 15;
    _scope = widget.existingRule?.scope ?? ClassReminderScope.oneTime;
    _custom = !_presetMinutes.contains(_minutes);
    _customController = TextEditingController(text: '$_minutes');
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = L.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.classReminderSheetTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            RadioGroup<int>(
              groupValue: _custom ? -1 : _minutes,
              onChanged: (value) {
                if (_saving) return;
                setState(() {
                  _custom = value == -1;
                  if (!_custom) _minutes = value!;
                });
              },
              child: Column(
                children: [
                  for (final minutes in _presetMinutes)
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      value: minutes,
                      title: Text(_offsetLabel(strings, minutes)),
                    ),
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: -1,
                    title: Text(strings.classReminderCustom),
                  ),
                ],
              ),
            ),
            if (_custom)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: TextField(
                  controller: _customController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: strings.classReminderCustomMinutes,
                    suffixText: 'min',
                  ),
                ),
              ),
            const Divider(height: 24),
            SegmentedButton<ClassReminderScope>(
              segments: [
                ButtonSegment(
                  value: ClassReminderScope.oneTime,
                  label: Text(strings.classReminderThisOccurrence),
                  icon: const Icon(Icons.event_outlined),
                ),
                ButtonSegment(
                  value: ClassReminderScope.recurring,
                  label: Text(strings.classReminderEveryOccurrence),
                  icon: const Icon(Icons.event_repeat_outlined),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: _saving
                  ? null
                  : (selection) => setState(() => _scope = selection.first),
            ),
            if (_scope == ClassReminderScope.recurring) ...[
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final colors = Theme.of(context).colorScheme;
                  return Card(
                    color: colors.secondaryContainer,
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: colors.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.classReminderMatchingTitle,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: colors.onSecondaryContainer,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  strings.classReminderMatchingDescription,
                                  style: TextStyle(
                                    color: colors.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || !_canSave ? null : _save,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(strings.classReminderSave),
            ),
            if (widget.existingRule != null && widget.onRemove != null)
              TextButton(
                onPressed: _saving ? null : _remove,
                child: Text(strings.classReminderRemove),
              ),
          ],
        ),
      ),
    );
  }

  String _offsetLabel(L strings, int minutes) => switch (minutes) {
    5 => strings.classReminderFiveMinutes,
    15 => strings.classReminderFifteenMinutes,
    30 => strings.classReminderThirtyMinutes,
    60 => strings.classReminderOneHour,
    _ => strings.classReminderCustom,
  };

  bool get _canSave =>
      !_custom || (int.tryParse(_customController.text) ?? 0) > 0;

  Future<void> _save() async {
    final customMinutes = int.tryParse(_customController.text);
    final minutes = _custom ? customMinutes : _minutes;
    if (minutes == null || minutes <= 0) return;
    setState(() => _saving = true);
    await widget.onSave(Duration(minutes: minutes), _scope);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    await widget.onRemove!();
    if (mounted) Navigator.of(context).pop();
  }
}
