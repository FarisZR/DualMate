import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';
import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/notification_api.dart';
import 'package:dualmate/native/widget/widget_helper.dart';
import 'package:dualmate/schedule/business/schedule_source_identity.dart';
import 'package:dualmate/schedule/model/schedule_source_type.dart';
import 'package:dualmate/schedule/model/timetable_configuration.dart';
import 'package:dualmate/schedule/reminders/class_reminder_controller.dart';
import 'package:dualmate/schedule/service/rapla/rapla_schedule_source.dart';
import 'package:dualmate/schedule/ui/customization/timetable_customization_view_model.dart';
import 'package:dualmate/schedule/ui/customization/timetable_module_tile.dart';
import 'package:dualmate/dualis/model/credentials.dart';

typedef _TimetableDraft = ({
  TimetableConfiguration configuration,
  Credentials? credentials,
});

class TimetableCustomizationPage extends StatefulWidget {
  final TimetableCustomizationViewModel? viewModel;
  const TimetableCustomizationPage({super.key, this.viewModel});
  @override
  State<TimetableCustomizationPage> createState() =>
      _TimetableCustomizationPageState();
}

class _TimetableCustomizationPageState
    extends State<TimetableCustomizationPage> {
  late final TimetableCustomizationViewModel model;
  bool _canPop = false;
  final Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    final c = KiwiContainer();
    model =
        widget.viewModel ??
        TimetableCustomizationViewModel(
          repository: c.resolve(),
          sourceProvider: c.resolve(),
          scheduleProvider: c.resolve(),
          entryRepository: c.resolve(),
          reminders: c.isRegistered<ClassReminderController>()
              ? c.resolve<ClassReminderController>()
              : null,
          widgets: c.isRegistered<WidgetHelper>()
              ? c.resolve<WidgetHelper>()
              : null,
          notifications: c.isRegistered<NotificationApi>()
              ? c.resolve<NotificationApi>()
              : null,
        );
    model.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) model.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (model.saving) return;
    if (model.dirty) {
      final l = L.of(context);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.timetableDiscardTitle),
          content: Text(l.timetableDiscardMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.dialogCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.timetableDiscard),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, false);
    });
  }

  Future<void> _save() async {
    try {
      await model.save();
      if (!mounted) return;
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (_) {
      if (mounted) _showError(L.of(context).timetableSaveError);
    }
  }

  void _showError(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _configure([TimetableConfiguration? source]) async {
    final draft = await showDialog<_TimetableDraft>(
      context: context,
      builder: (_) => _ConfigureTimetableDialog(
        source: source,
        primary: model.sources.isEmpty || source?.id == model.sources.first.id,
        credentials: model.dualisCredentials,
      ),
    );
    if (draft == null || !mounted) return;
    final configured = draft.configuration;
    if (model.sources.any((s) => s.id == configured.id && s.id != source?.id)) {
      _showError(L.of(context).timetableDuplicate);
      return;
    }
    try {
      await model.put(
        configured,
        replacingId: source?.id,
        dualisCredentials: draft.credentials,
      );
    } catch (_) {
      if (mounted) _showError(L.of(context).timetableLoadError);
    }
  }

  Future<void> _remove(TimetableConfiguration source) async {
    final l = L.of(context);
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.timetableRemoveTitle.replaceAll('{name}', source.label)),
        content: Text(l.timetableRemoveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.dialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.timetableRemove),
          ),
        ],
      ),
    );
    if (remove == true) model.remove(source);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) => PopScope(
        canPop: _canPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: _close,
              icon: const Icon(Icons.arrow_back),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            ),
          ),
          body: IgnorePointer(
            ignoring: model.saving || model.loadingSource,
            child: model.loading
                ? const Center(child: CircularProgressIndicator())
                : model.loadFailed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.timetableLoadError),
                        TextButton(
                          onPressed: model.load,
                          child: Text(l.timetableRetry),
                        ),
                      ],
                    ),
                  )
                : Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.timetableCustomize,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    l.timetableDescription,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  if (model.loadingSource)
                                    const LinearProgressIndicator(),
                                ],
                              ),
                            ),
                          ),
                          for (var i = 0; i < model.sources.length; i++) ...[
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: _TimetableGroupHeader(
                                  key: ValueKey(model.sources[i].id),
                                  source: model.sources[i],
                                  primary: i == 0,
                                  expanded: !_collapsed.contains(
                                    model.sources[i].id,
                                  ),
                                  modules:
                                      model.modules[model.sources[i].id] ?? [],
                                  onExpansionChanged: () => setState(() {
                                    if (!_collapsed.add(model.sources[i].id))
                                      _collapsed.remove(model.sources[i].id);
                                  }),
                                  onEdit: () => _configure(model.sources[i]),
                                  onRemove: () => _remove(model.sources[i]),
                                  onRefresh: () =>
                                      model.refreshModules(model.sources[i]),
                                ),
                              ),
                            ),
                            if (!_collapsed.contains(model.sources[i].id))
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  24,
                                ),
                                sliver: SliverList.builder(
                                  itemCount:
                                      (model.modules[model.sources[i].id] ?? [])
                                          .length,
                                  itemBuilder: (context, index) {
                                    final source = model.sources[i];
                                    final title =
                                        model.modules[source.id]![index];
                                    return Padding(
                                      key: ValueKey('${source.id}/$title'),
                                      padding: const EdgeInsets.only(top: 4),
                                      child: TimetableModuleTile(
                                        title: title,
                                        selected: source.includes(title),
                                        onChanged: (selected) => model.toggle(
                                          source,
                                          title,
                                          selected,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            sliver: SliverToBoxAdapter(
                              child: Card.filled(
                                margin: EdgeInsets.zero,
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: .045),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  leading: Icon(
                                    Icons.add,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    size: 30,
                                  ),
                                  title: Text(
                                    l.timetableAdd,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(l.timetableAddDescription),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: model.saving
                                      ? null
                                      : () => _configure(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Align(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('timetable_save_changes'),
                    onPressed:
                        model.loading ||
                            model.loadFailed ||
                            model.saving ||
                            model.loadingSource
                        ? null
                        : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: model.saving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l.timetableSave),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimetableGroupHeader extends StatefulWidget {
  final TimetableConfiguration source;
  final bool primary, expanded;
  final List<String> modules;
  final VoidCallback onEdit, onRemove, onExpansionChanged;
  final Future<void> Function() onRefresh;
  const _TimetableGroupHeader({
    super.key,
    required this.source,
    required this.primary,
    required this.expanded,
    required this.modules,
    required this.onEdit,
    required this.onRemove,
    required this.onExpansionChanged,
    required this.onRefresh,
  });
  @override
  State<_TimetableGroupHeader> createState() => _TimetableGroupHeaderState();
}

class _TimetableGroupHeaderState extends State<_TimetableGroupHeader> {
  bool refreshing = false;
  Future<void> _refresh() async {
    setState(() => refreshing = true);
    try {
      await widget.onRefresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L.of(context).timetableLoadError)),
        );
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final colors = Theme.of(context).colorScheme;
    final selected = widget.modules.where(widget.source.includes).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          expanded: widget.expanded,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 25,
              backgroundColor: colors.primary.withValues(alpha: .10),
              child: Icon(Icons.calendar_today_outlined, color: colors.primary),
            ),
            title: Text(
              widget.source.label,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${widget.primary ? l.timetableMyClass : l.timetableAdditional} · ${_sourceName(l, widget.source.type)}\n${l.timetableSelectedCount.replaceAll('{selected}', '$selected').replaceAll('{total}', '${widget.modules.length}')}',
            ),
            onTap: widget.onExpansionChanged,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<String>(
                  tooltip: l.timetableOptions,
                  onSelected: (choice) {
                    if (choice == 'edit') widget.onEdit();
                    if (choice == 'remove') widget.onRemove();
                    if (choice == 'refresh') _refresh();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(l.timetableEdit)),
                    PopupMenuItem(
                      value: 'refresh',
                      child: Text(l.timetableRefresh),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(l.timetableRemove),
                    ),
                  ],
                ),
                AnimatedRotation(
                  turns: widget.expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more),
                ),
              ],
            ),
          ),
        ),
        if (refreshing) const LinearProgressIndicator(),
        if (widget.expanded && widget.modules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(l.timetableNoModules),
                TextButton.icon(
                  onPressed: refreshing ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(l.timetableRefresh),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _sourceName(L l, ScheduleSourceType type) => switch (type) {
  ScheduleSourceType.Rapla => l.scheduleSourceTypeRapla,
  ScheduleSourceType.Ical => l.scheduleSourceTypeIcal,
  ScheduleSourceType.Dualis => l.scheduleSourceTypeDualis,
  ScheduleSourceType.None => l.scheduleSourceTypeNone,
};

class _ConfigureTimetableDialog extends StatefulWidget {
  final TimetableConfiguration? source;
  final bool primary;
  final Credentials credentials;
  const _ConfigureTimetableDialog({
    this.source,
    required this.primary,
    required this.credentials,
  });
  @override
  State<_ConfigureTimetableDialog> createState() =>
      _ConfigureTimetableDialogState();
}

class _ConfigureTimetableDialogState extends State<_ConfigureTimetableDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController label;
  late final TextEditingController url;
  late final TextEditingController username;
  late final TextEditingController password;
  late ScheduleSourceType type;
  @override
  void initState() {
    super.initState();
    label = TextEditingController(text: widget.source?.label);
    url = TextEditingController(text: widget.source?.value);
    username = TextEditingController(text: widget.credentials.username);
    password = TextEditingController(text: widget.credentials.password);
    type = widget.source?.type ?? ScheduleSourceType.Rapla;
  }

  @override
  void dispose() {
    label.dispose();
    url.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!form.currentState!.validate()) return;
    final credentials = type == ScheduleSourceType.Dualis
        ? Credentials(username.text.trim(), password.text)
        : null;
    final value = credentials?.username ?? url.text.trim();
    final id = type == widget.source?.type && value == widget.source?.value
        ? widget.source!.id
        : ScheduleSourceIdentity.create(type, value);
    Navigator.pop(context, (
      configuration: TimetableConfiguration(
        id: id,
        label: label.text.trim(),
        type: type,
        value: value,
        includeAll: widget.source?.includeAll ?? widget.primary,
        exceptions: id == widget.source?.id ? widget.source!.exceptions : {},
      ),
      credentials: credentials,
    ));
  }

  bool _canSelect(ScheduleSourceType source) =>
      source != ScheduleSourceType.None &&
      (source != ScheduleSourceType.Dualis ||
          widget.primary ||
          widget.source?.type == source);

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? L.of(context).timetableRequired
      : null;

  String? _validateUrl(String? value) {
    final l = L.of(context);
    final text = value?.trim() ?? '';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return l.timetableInvalidUrl;
    }
    if (type == ScheduleSourceType.Rapla &&
        !RaplaScheduleSource.isValidUrl(text)) {
      return l.timetableInvalidUrl;
    }
    return null;
  }

  Widget _credentialsFields(L l) => AutofillGroup(
    onDisposeAction: AutofillContextAction.cancel,
    child: Column(
      children: [
        Text(l.onboardingDualisSourceDescription),
        const SizedBox(height: 16),
        TextFormField(
          controller: username,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: l.loginUsername),
          autofillHints: const [AutofillHints.username, 'dualis.dhbw.de'],
          textInputAction: TextInputAction.next,
          validator: _required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: l.loginPassword),
          autofillHints: const [AutofillHints.password, 'dualis.dhbw.de'],
          validator: _required,
          onFieldSubmitted: (_) => _submit(),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AlertDialog(
      title: Text(widget.source == null ? l.timetableAdd : l.timetableEdit),
      content: SizedBox(
        width: 440,
        child: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: label,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: l.timetableClassName),
                  validator: _required,
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<ScheduleSourceType>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.timetableSource),
                  items: [
                    for (final source in ScheduleSourceType.values.where(
                      _canSelect,
                    ))
                      DropdownMenuItem(
                        value: source,
                        child: Text(_sourceName(l, source)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null)
                      setState(() {
                        type = value;
                        url.clear();
                      });
                  },
                ),
                const SizedBox(height: 20),
                if (type == ScheduleSourceType.Dualis)
                  _credentialsFields(l)
                else
                  TextFormField(
                    controller: url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(labelText: l.timetableUrl),
                    validator: _validateUrl,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.dialogCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.dialogOk)),
      ],
    );
  }
}
