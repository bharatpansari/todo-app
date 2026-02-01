import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ProService extends ChangeNotifier {
  static const String _boxName = 'pro_status';
  static const String _keyIsPro = 'is_pro';
  
  bool _isPro = false;
  bool get isPro => _isPro;

  ProService() {
    _init();
  }

  Future<void> _init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<bool>(_boxName);
      }
      final box = Hive.box<bool>(_boxName);
      _isPro = box.get(_keyIsPro, defaultValue: false) ?? false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("ProService init error: $e");
    }
  }

  Future<void> purchasePro() async {
    // Stub implementation: Instant success
    await _setProStatus(true);
  }

  Future<void> restorePurchases() async {
    // Stub implementation: Instant success
    // In real app, query underlying store
    await _setProStatus(true);
  }

  Future<void> debugReset() async {
    await _setProStatus(false);
  }

  Future<void> _setProStatus(bool status) async {
    _isPro = status;
    final box = Hive.box<bool>(_boxName);
    await box.put(_keyIsPro, status);
    notifyListeners();
  }

  // Feature Limits
  bool get canAddCategory => isPro; // If strictly checking limit, pass count
  bool get canAddLabel => isPro; 
  bool get canAddMultipleReminders => isPro;
  bool get canUseBoardView => isPro;
  bool get canUseCalendarView => isPro;
  bool get canUseVoice => isPro;
  bool get canUseTemplates => isPro;
  
  // Specific count checks (True if allowed, False if blocked)
  bool canAddMoreCategories(int currentCount) {
    if (isPro) return true;
    return currentCount < 5;
  }

  bool canAddMoreLabels(int currentCount) {
    if (isPro) return true;
    return currentCount < 10;
  }
}
