import 'package:dualmate/common/data/preferences/preferences_provider.dart';
import 'package:flutter/material.dart';
import 'package:kiwi/kiwi.dart';

///
/// This widget uses a [List<PageDefinition>] instance and displays a bottom
/// bar which displays the individual pages and allows navigating to them.
///
/// If the [PageDefinition] has a viewModel it provides it using a
/// [ChangeNotifierProvider]
///
/// When a [pagesId] is provided, the active page is saved
///
class PagerWidget extends StatefulWidget {
  final List<PageDefinition> pages;
  final String? pagesId;
  final ValueNotifier<int?>? forcedPage;

  const PagerWidget({
    Key? key,
    required this.pages,
    this.pagesId,
    this.forcedPage,
  }) : super(key: key);

  @override
  _PagerWidgetState createState() => _PagerWidgetState(pages, pagesId);
}

class _PagerWidgetState extends State<PagerWidget> {
  final PreferencesProvider preferencesProvider = KiwiContainer().resolve();

  final String? pagesId;
  final List<PageDefinition> pages;
  int _currentPage = 0;
  DateTime? _lastSwitchAt;
  static const Duration _switchThrottle = Duration(milliseconds: 300);

  _PagerWidgetState(this.pages, this.pagesId);

  @override
  void initState() {
    super.initState();

    loadActivePage();
    widget.forcedPage?.addListener(_handleForcedPage);
    _handleForcedPage();
  }

  @override
  void dispose() {
    widget.forcedPage?.removeListener(_handleForcedPage);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          key: ValueKey(_currentPage),
          children: <Widget>[
            Expanded(
              child: pages[_currentPage].builder(context),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentPage,
        onTap: (int index) async {
          await setActivePage(index);
        },
        items: buildBottomNavigationBarItems(),
      ),
    );
  }

  List<BottomNavigationBarItem> buildBottomNavigationBarItems() {
    var bottomNavigationBarItems = <BottomNavigationBarItem>[];

    for (var page in pages) {
      bottomNavigationBarItems.add(
        BottomNavigationBarItem(
          icon: page.icon,
          label: page.text,
        ),
      );
    }
    return bottomNavigationBarItems;
  }

  Future<void> setActivePage(int page, {bool force = false}) async {
    if (page < 0 || page >= pages.length) {
      return;
    }
    var now = DateTime.now();
    if (!force &&
        _lastSwitchAt != null &&
        now.difference(_lastSwitchAt!) < _switchThrottle) {
      return;
    }
    _lastSwitchAt = now;

    setState(() {
      _currentPage = page;
    });
    if (pagesId != null) {
      await preferencesProvider.set("${pagesId}_active_page", page);
    }
  }

  Future<void> loadActivePage() async {
    if (pagesId == null) return;

    var selectedPage = await preferencesProvider.get<int>(
      "${pagesId}_active_page",
    );

    if (selectedPage != null &&
        selectedPage > 0 &&
        selectedPage < pages.length) {
      setState(() {
        _currentPage = selectedPage;
      });
    }
  }

  void _handleForcedPage() async {
    final forced = widget.forcedPage?.value;
    if (forced == null) return;
    await setActivePage(forced, force: true);
    widget.forcedPage?.value = null;
  }
}

class PageDefinition {
  final Widget icon;
  final String text;
  final WidgetBuilder builder;

  PageDefinition({
    required this.icon,
    required this.text,
    required this.builder,
  });
}
