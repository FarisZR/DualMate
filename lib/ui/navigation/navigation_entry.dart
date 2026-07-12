import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class NavigationEntry<T extends BaseViewModel> {
  T? _viewModel;
  Future<void>? _preparation;
  NavigationEntryLifecycle _lifecycle = NavigationEntryLifecycle.cold;

  String get route;

  String title(BuildContext context);

  Widget icon(BuildContext context);

  NavigationEntryLifecycle get lifecycle => _lifecycle;

  Future<void> prepare() {
    _resetDisposedViewModel();
    final existingPreparation = _preparation;
    if (existingPreparation != null) {
      return existingPreparation;
    }

    _lifecycle = NavigationEntryLifecycle.preparing;
    final preparation = _prepare();
    _preparation = preparation;
    return preparation;
  }

  Future<void> _prepare() async {
    try {
      viewModel();
      await prepareSection();
      if (_lifecycle != NavigationEntryLifecycle.active) {
        _lifecycle = NavigationEntryLifecycle.prepared;
      }
    } catch (_) {
      if (_lifecycle != NavigationEntryLifecycle.active) {
        _lifecycle = NavigationEntryLifecycle.failed;
      }
      _preparation = null;
      rethrow;
    }
  }

  /// Hook for section-owned view-model/cache preparation. It must not mount
  /// widgets; activation is the only lifecycle phase that builds a route.
  Future<void> prepareSection() async {}

  Widget activate(BuildContext context) {
    final model = viewModel();
    _lifecycle = NavigationEntryLifecycle.active;
    return ChangeNotifierProvider<T>.value(value: model, child: build(context));
  }

  Widget buildRoute(BuildContext context) => activate(context);

  Widget build(BuildContext context);

  T viewModel() {
    _resetDisposedViewModel();
    _viewModel ??= initViewModel();
    return _viewModel!;
  }

  void _resetDisposedViewModel() {
    if (!(_viewModel?.isDisposed ?? false)) return;
    _viewModel = null;
    _preparation = null;
    _lifecycle = NavigationEntryLifecycle.cold;
  }

  T initViewModel();

  List<Widget> appBarActions(BuildContext context) => [];
}

enum NavigationEntryLifecycle { cold, preparing, prepared, active, failed }
