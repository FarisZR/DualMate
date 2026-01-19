import 'package:dhbwstudentapp/common/ui/viewmodels/base_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

abstract class NavigationEntry<T extends BaseViewModel> {
  T? _viewModel;

  String get route;

  String title(BuildContext context);

  Widget icon(BuildContext context);

  Widget buildRoute(BuildContext context) {
    var model = viewModel();
    return ChangeNotifierProvider<T>.value(
      value: model,
      child: build(context),
    );
  }

  Widget build(BuildContext context);

  T viewModel() {
    _viewModel ??= initViewModel();
    return _viewModel!;
  }

  T initViewModel();

  List<Widget> appBarActions(BuildContext context) => [];
}
