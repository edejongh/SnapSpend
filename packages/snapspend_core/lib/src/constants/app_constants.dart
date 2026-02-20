class AppConstants {
  static const String defaultCurrency = 'ZAR';
  static const List<String> supportedCurrencies = [
    'ZAR',
    'USD',
    'EUR',
    'GBP',
    'KES',
    'NGN',
    'BWP',
    'MZN',
    'ZMW',
    'GHS',
  ];
  static const double ocrConfidenceThreshold = 0.70;
  static const double ocrFlagThreshold = 0.50;
  static const int freeMonthlyScansLimit = 20;
}
