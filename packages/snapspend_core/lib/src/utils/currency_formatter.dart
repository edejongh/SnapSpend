class CurrencyFormatter {
  static String format(double amount, String currencyCode) {
    final symbol = _symbolFor(currencyCode);
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      buffer.write(intPart[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write(',');
    }
    final intFormatted = buffer.toString().split('').reversed.join();
    return '$symbol$intFormatted.$decPart';
  }

  static String _symbolFor(String code) {
    const symbols = {
      'ZAR': 'R',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'KES': 'KSh',
      'NGN': '₦',
      'BWP': 'P',
      'MZN': 'MT',
      'ZMW': 'ZK',
      'GHS': 'GH₵',
    };
    return symbols[code] ?? code;
  }

  static double parseAmount(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}
