import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _goalKey = 'monthly_spending_goal';

/// Nullable — null means no goal set.
final monthlyGoalProvider = StateProvider<double?>((ref) => null);

class MonthlyGoalService {
  static Future<double?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getDouble(_goalKey);
    return raw;
  }

  static Future<void> save(double? goal) async {
    final prefs = await SharedPreferences.getInstance();
    if (goal == null) {
      await prefs.remove(_goalKey);
    } else {
      await prefs.setDouble(_goalKey, goal);
    }
  }
}
