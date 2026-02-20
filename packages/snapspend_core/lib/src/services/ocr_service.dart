class OcrResult {
  final String rawText;
  final double confidence;
  final double? extractedAmount;
  final DateTime? extractedDate;
  final String? extractedVendor;
  final String? suggestedCategory;

  const OcrResult({
    required this.rawText,
    required this.confidence,
    this.extractedAmount,
    this.extractedDate,
    this.extractedVendor,
    this.suggestedCategory,
  });
}

abstract class OcrService {
  Future<OcrResult> processImage(String imagePath);
}
