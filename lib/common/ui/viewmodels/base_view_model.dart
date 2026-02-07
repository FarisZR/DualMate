import 'package:property_change_notifier/property_change_notifier.dart';

class BaseViewModel extends PropertyChangeNotifier<String> {
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void notifyIfMounted(String property) {
    if (_isDisposed) return;
    notifyListeners(property);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
