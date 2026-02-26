class OcrResult {
  final String rawText;
  final double confidence;
  final double? extractedAmount;
  final DateTime? extractedDate;
  final String? extractedVendor;
  final String? suggestedCategory;
  /// Local file path of the captured image — set by the snap screen so the
  /// review screen can upload it to Firebase Storage on save.
  final String? imagePath;

  const OcrResult({
    required this.rawText,
    required this.confidence,
    this.extractedAmount,
    this.extractedDate,
    this.extractedVendor,
    this.suggestedCategory,
    this.imagePath,
  });
}

abstract class OcrService {
  Future<OcrResult> processImage(String imagePath);
}
