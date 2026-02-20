import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:snapspend_core/snapspend_core.dart';

class OcrServiceImpl implements OcrService {
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<OcrResult> processImage(String imagePath) async {
    final inputImage = InputImage.fromFile(File(imagePath));
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final rawText = recognizedText.text;
    final confidence = _estimateConfidence(recognizedText);
    final amount = _extractAmount(rawText);
    final date = _extractDate(rawText);
    final vendor = _extractVendor(rawText);
    final category = _suggestCategory(rawText);

    return OcrResult(
      rawText: rawText,
      confidence: confidence,
      extractedAmount: amount,
      extractedDate: date,
      extractedVendor: vendor,
      suggestedCategory: category,
    );
  }

  double _estimateConfidence(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return 0.0;
    // ML Kit doesn't expose per-block confidence on all platforms;
    // use block count as a proxy
    final blockCount = recognizedText.blocks.length;
    if (blockCount >= 5) return 0.85;
    if (blockCount >= 2) return 0.65;
    return 0.40;
  }

  double? _extractAmount(String text) {
    // Match patterns like R 123.45, 123,45, 123.45, R123.45
    final patterns = [
      RegExp(r'R\s*(\d{1,6}[.,]\d{2})', caseSensitive: false),
      RegExp(r'TOTAL[:\s]+R?\s*(\d{1,6}[.,]\d{2})', caseSensitive: false),
      RegExp(r'AMOUNT[:\s]+R?\s*(\d{1,6}[.,]\d{2})', caseSensitive: false),
      RegExp(r'(\d{1,6}\.\d{2})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)!.replaceAll(',', '.');
        return double.tryParse(raw);
      }
    }
    return null;
  }

  DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(r'(\d{2})[/\-.](\d{2})[/\-.](\d{4})'),
      RegExp(r'(\d{4})[/\-.](\d{2})[/\-.](\d{2})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          if (match.group(1)!.length == 4) {
            return DateTime(
              int.parse(match.group(1)!),
              int.parse(match.group(2)!),
              int.parse(match.group(3)!),
            );
          }
          return DateTime(
            int.parse(match.group(3)!),
            int.parse(match.group(2)!),
            int.parse(match.group(1)!),
          );
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  String? _extractVendor(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    // Heuristic: the vendor is often in the first non-empty line
    if (lines.isNotEmpty && lines.first.length >= 3) {
      return lines.first;
    }
    return null;
  }

  String? _suggestCategory(String text) {
    final lower = text.toLowerCase();
    for (final category in CategoryConstants.defaultCategories) {
      for (final keyword in category.keywords) {
        if (lower.contains(keyword)) return category.categoryId;
      }
    }
    return 'other';
  }

  void dispose() {
    _textRecognizer.close();
  }
}
