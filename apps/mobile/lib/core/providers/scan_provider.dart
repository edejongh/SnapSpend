import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapspend_core/snapspend_core.dart';

String _scanKey() {
  final now = DateTime.now();
  return 'scan_count_${now.year}_${now.month.toString().padLeft(2, '0')}';
}

/// Current monthly OCR scan count (0 if no scans yet).
final monthlyScanCountProvider = StateProvider<int>((ref) => 0);

class ScanCountService {
  static Future<int> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scanKey()) ?? 0;
  }

  static Future<int> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _scanKey();
    final current = prefs.getInt(key) ?? 0;
    final updated = current + 1;
    await prefs.setInt(key, updated);
    return updated;
  }
}

int get scanLimit => AppConstants.freeMonthlyScansLimit;
int scansRemaining(int used) => (scanLimit - used).clamp(0, scanLimit);
