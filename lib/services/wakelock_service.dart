import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WakelockService {
  static const String _keepScreenAwakeKey = 'keep_screen_awake_during_stats';
  
  /// Get user preference for keeping screen awake
  static Future<bool> getKeepScreenAwakePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepScreenAwakeKey) ?? true; // Default to true
  }
  
  /// Set user preference for keeping screen awake
  static Future<void> setKeepScreenAwakePreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepScreenAwakeKey, enabled);
  }
  
  /// Enable wake lock if user preference allows it
  static Future<void> enableWakelockIfAllowed() async {
    final shouldKeepAwake = await getKeepScreenAwakePreference();
    if (shouldKeepAwake) {
      await WakelockPlus.enable();
      print('Screen wake lock enabled for stats tracking');
    }
  }
  
  /// Disable wake lock
  static Future<void> disableWakelock() async {
    await WakelockPlus.disable();
    print('Screen wake lock disabled');
  }
  
  /// Check if wake lock is currently enabled
  static Future<bool> isWakelockEnabled() async {
    return await WakelockPlus.enabled;
  }
}