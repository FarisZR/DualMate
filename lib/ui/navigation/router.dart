import 'package:dualmate/canteen/ui/canteen_navigation_entry.dart';
import 'package:dualmate/date_management/ui/date_management_navigation_entry.dart';
import 'package:dualmate/dualis/ui/dualis_navigation_entry.dart';
import 'package:dualmate/information/ui/useful_information_navigation_entry.dart';
import 'package:dualmate/schedule/ui/schedule_navigation_entry.dart';
import 'package:dualmate/ui/main_page.dart';
import 'package:dualmate/ui/navigation/navigation_entry.dart';
import 'package:dualmate/ui/onboarding/onboarding_page.dart';
import 'package:dualmate/ui/settings/settings_page.dart';
import 'package:flutter/material.dart';

final List<NavigationEntry> navigationEntries = [
  ScheduleNavigationEntry(),
  CanteenNavigationEntry(),
  DualisNavigationEntry(),
  DateManagementNavigationEntry(),
  UsefulInformationNavigationEntry(),
];

WidgetBuilder _resolveRoute(RouteSettings settings) {
  for (var route in navigationEntries) {
    if (route.route == settings.name) {
      return route.buildRoute;
    }
  }
  return (_) => Container();
}

Route<dynamic> generateDrawerRoute(RouteSettings settings) {
  print("=== === === === === === Navigating to: ${settings.name}");

  final args = settings.arguments;
  if (args is Map && args["disableTransitions"] == true) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _resolveRoute(settings)(context);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  if (settings.name == "shell") {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Container(color: Theme.of(context).scaffoldBackgroundColor);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  final widget = _resolveRoute(settings);

  return PageRouteBuilder(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => widget(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const offsetBegin = Offset(0.0, 0.005);
      final offsetEnd = Offset.zero;
      final offsetTween = Tween(begin: offsetBegin, end: offsetEnd)
          .chain(CurveTween(curve: Curves.fastOutSlowIn));

      const opacityBegin = 0.0;
      const opacityEnd = 1.0;
      final opacityTween = Tween(begin: opacityBegin, end: opacityEnd)
          .chain(CurveTween(curve: Curves.fastOutSlowIn));

      return SlideTransition(
        position: animation.drive(offsetTween),
        child: FadeTransition(
          opacity: animation.drive(opacityTween),
          child: Container(
            child: child,
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
      );
    },
  );
}

Route<dynamic> generateRoute(RouteSettings settings) {
  print("=== === === === === === Navigating to: ${settings.name}");
  Widget target;

  switch (settings.name) {
    case "onboarding":
      target = const OnboardingPage();
      break;
    case "main":
      target = const MainPage();
      break;
    case "settings":
      target = SettingsPage();
      break;
    default:
      print("Failed to navigate to: " + (settings.name ?? ""));
      target = Container();
  }

  return MaterialPageRoute(builder: (_) => target, settings: settings);
}
