import 'package:dio/dio.dart';
import 'package:snapspend_core/snapspend_core.dart';

class CurrencyServiceImpl implements CurrencyService {
  final _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.frankfurter.dev/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  // In-memory rate cache: 'USD_ZAR' → 18.52
  final _cache = <String, double>{};

  @override
  Future<Map<String, double>> getRates(String baseCurrency) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/latest',
      queryParameters: {'base': baseCurrency},
    );
    final raw = response.data?['rates'] as Map<String, dynamic>? ?? {};
    final rates = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
    rates[baseCurrency] = 1.0;
    return rates;
  }

  @override
  Future<double> convert(
    double amount,
    String fromCurrency,
    String toCurrency,
  ) async {
    if (fromCurrency == toCurrency) return amount;
    final key = '${fromCurrency}_$toCurrency';
    if (!_cache.containsKey(key)) {
      try {
        final rates = await getRates(fromCurrency);
        final rate = rates[toCurrency];
        if (rate != null) _cache[key] = rate;
      } catch (_) {
        // Network error — fall back to 1:1
        return amount;
      }
    }
    return amount * (_cache[key] ?? 1.0);
  }
}
