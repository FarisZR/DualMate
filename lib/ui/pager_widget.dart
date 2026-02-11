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
  final Set<int> _loadedPages = <int>{};
  final Map<int, Widget> _pageCache = {};

  _PagerWidgetState(this.pages, this.pagesId);

  @override
  void initState() {
    super.initState();

    loadActivePage();
    _loadedPages.add(_currentPage);
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
      body: IndexedStack(
        index: _currentPage,
        children: List.generate(
          pages.length,
          (index) => _buildPage(context, index),
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

    setState(() {
      _currentPage = page;
      _loadedPages.add(page);
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
        _loadedPages.add(selectedPage);
      });
    }
  }

  void _handleForcedPage() async {
    final forced = widget.forcedPage?.value;
    if (forced == null) return;
    await setActivePage(forced, force: true);
    widget.forcedPage?.value = null;
  }

  Widget _buildPage(BuildContext context, int index) {
    if (!_loadedPages.contains(index)) {
      return const SizedBox.shrink();
    }
    return _pageCache.putIfAbsent(index, () => pages[index].builder(context));
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
