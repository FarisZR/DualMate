import 'dart:async';

import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prepares once before activation and does not build early', (
    tester,
  ) async {
    final gate = Completer<void>();
    final entry = _FakeNavigationEntry(preparationGate: gate);

    final preparation = entry.prepare();
    expect(identical(preparation, entry.prepare()), isTrue);
    expect(entry.events, ['viewModel', 'prepare']);
    expect(entry.lifecycle, NavigationEntryLifecycle.preparing);
    gate.complete();
    await preparation;
    expect(entry.lifecycle, NavigationEntryLifecycle.prepared);
    expect(entry.events, ['viewModel', 'prepare', 'prepared']);

    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: (context) => entry.activate(context))),
    );
    expect(find.text('prepared route'), findsOneWidget);
    expect(entry.events, ['viewModel', 'prepare', 'prepared', 'build']);
    expect(entry.lifecycle, NavigationEntryLifecycle.active);
  });

  testWidgets('activation stays active while preparation finishes later', (
    tester,
  ) async {
    final gate = Completer<void>();
    final entry = _FakeNavigationEntry(preparationGate: gate);
    final preparation = entry.prepare();

    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: (context) => entry.activate(context))),
    );
    expect(entry.lifecycle, NavigationEntryLifecycle.active);
    expect(find.text('prepared route'), findsOneWidget);

    gate.complete();
    await preparation;
    expect(entry.lifecycle, NavigationEntryLifecycle.active);
  });
}

class _FakeNavigationEntry extends NavigationEntry<_FakeViewModel> {
  _FakeNavigationEntry({this.preparationGate});

  final Completer<void>? preparationGate;
  final List<String> events = <String>[];

  @override
  String get route => 'fake';

  @override
  String title(BuildContext context) => 'Fake';

  @override
  Widget icon(BuildContext context) => const Icon(Icons.circle);

  @override
  _FakeViewModel initViewModel() {
    events.add('viewModel');
    return _FakeViewModel();
  }

  @override
  Future<void> prepareSection() async {
    events.add('prepare');
    final gate = preparationGate;
    if (gate != null) {
      await gate.future;
    }
    events.add('prepared');
  }

  @override
  Widget build(BuildContext context) {
    events.add('build');
    return const Text('prepared route');
  }
}

class _FakeViewModel extends BaseViewModel {}
