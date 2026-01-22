import 'package:dhbwstudentapp/common/i18n/localizations.dart';
import 'package:dhbwstudentapp/common/logging/analytics.dart';
import 'package:dhbwstudentapp/common/ui/colors.dart';
import 'package:dhbwstudentapp/common/ui/viewmodels/root_view_model.dart';
import 'package:dhbwstudentapp/common/appstart/app_initializer.dart';
import 'package:dhbwstudentapp/common/util/launch_intent.dart';
import 'package:dhbwstudentapp/main.dart';
import 'package:kiwi/kiwi.dart';
import 'package:dhbwstudentapp/ui/navigation/navigator_key.dart';
import 'package:dhbwstudentapp/ui/navigation/router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:property_change_notifier/property_change_notifier.dart';

///
/// This is the top level widget of the app. It handles navigation of the
/// root navigator and rebuilds its child widgets on theme changes
///
class RootPage extends StatefulWidget {
  const RootPage({Key? key}) : super(key: key);

  @override
  _RootPageState createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  RootViewModel? _rootViewModel;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();
    await initializeAppBase(false);
    print("Root init: base ${stopwatch.elapsedMilliseconds}ms");
    await saveLastStartLanguage();
    print("Root init: save language ${stopwatch.elapsedMilliseconds}ms");
    _rootViewModel = RootViewModel(
      KiwiContainer().resolve(),
    );
    await _rootViewModel?.loadFromPreferences();
    print("Root init: prefs ${stopwatch.elapsedMilliseconds}ms");
    initializeAppBackground(false);

    WidgetsBinding.instance.allowFirstFrame();

    print("Root init: allow first frame ${stopwatch.elapsedMilliseconds}ms");

    if (!mounted) return;
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_rootViewModel == null) {
      return MaterialApp(
        home: const SizedBox.shrink(),
      );
    }

    return PropertyChangeProvider<RootViewModel, String>(
      child: PropertyChangeConsumer<RootViewModel, String>(
        properties: const ["appTheme", "isOnboarding"],
        builder: (
          BuildContext context,
          RootViewModel? model,
          Set<String>? properties,
        ) {
          if (model == null) return Container();
          return MaterialApp(
            theme: ColorPalettes.buildTheme(model.appTheme),
            initialRoute:
                model.isOnboarding ? "onboarding" : _resolveInitialRoute(),
            navigatorKey: NavigatorKey.rootKey,
            navigatorObservers: [rootNavigationObserver],
            localizationsDelegates: [
              const LocalizationDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('de'),
            ],
            onGenerateRoute: generateRoute,
          );
        },
      ),
      value: _rootViewModel!,
    );
  }

  String _resolveInitialRoute() {
    var defaultRoute = "main";
    if (WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
        LaunchIntent.canteen) {
      return "canteen";
    }
    if (WidgetsBinding.instance.platformDispatcher.defaultRouteName ==
        LaunchIntent.schedule) {
      return "schedule";
    }
    return defaultRoute;
  }
}
