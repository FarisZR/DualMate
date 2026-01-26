import 'package:dualmate/common/i18n/localizations.dart';
import 'package:dualmate/common/ui/viewmodels/base_view_model.dart';
import 'package:dualmate/information/ui/usefulinformation/useful_information_page.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:flutter/material.dart';

class UsefulInformationNavigationEntry extends NavigationEntry<BaseViewModel> {
  @override
  Widget build(BuildContext context) {
    return UsefulInformationPage();
  }

  @override
  Widget icon(BuildContext context) {
    return Icon(Icons.info_outline);
  }

  @override
  String title(BuildContext context) {
    return L.of(context).screenUsefulLinks;
  }

  @override
  String get route => "usefulInformation";

  @override
  BaseViewModel initViewModel() {
    return BaseViewModel();
  }
}
