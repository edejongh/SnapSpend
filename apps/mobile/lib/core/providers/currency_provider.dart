import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/currency_service_impl.dart';

final currencyServiceProvider = Provider<CurrencyServiceImpl>((ref) {
  return CurrencyServiceImpl();
});
