abstract class CurrencyService {
  Future<double> convert(
    double amount,
    String fromCurrency,
    String toCurrency,
  );

  Future<Map<String, double>> getRates(String baseCurrency);
}
