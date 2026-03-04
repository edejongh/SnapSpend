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
    // ML Kit doesn't expose per-block confidence on all platforms.
    // Combine block count with total character count: a genuine receipt
    // typically has 100+ characters and 5+ text blocks.
    final blockCount = recognizedText.blocks.length;
    final charCount = recognizedText.text.length;
    if (charCount >= 100 || blockCount >= 5) return 0.85;
    if (charCount >= 40 || blockCount >= 2) return 0.65;
    return 0.40;
  }

  double? _extractAmount(String text) {
    // Try labelled totals first (more reliable than bare currency symbols)
    // to avoid matching a line-item amount instead of the receipt total.
    final patterns = [
      RegExp(r'TOTAL[:\s]+R?\s*(\d{1,6}[.,]\d{2})', caseSensitive: false),
      RegExp(r'AMOUNT[:\s]+R?\s*(\d{1,6}[.,]\d{2})', caseSensitive: false),
      RegExp(r'DUE[:\s]+R?\s*(\d{1,6}[.,]\d{2})', caseSensitive: false),
      RegExp(r'R\s*(\d{1,6}[.,]\d{2})', caseSensitive: false),
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

  static const _monthNames = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
    'july': 7, 'august': 8, 'september': 9, 'october': 10,
    'november': 11, 'december': 12,
  };

  DateTime? _extractDate(String text) {
    // Pattern 1: DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    // Pattern 2: YYYY/MM/DD or YYYY-MM-DD
    // Pattern 3: DD/MM/YY (2-digit year)
    // Pattern 4: DD MMM YYYY or DD MMMM YYYY (e.g. "15 Feb 2026")
    // Pattern 5: MMM DD, YYYY or MMMM DD, YYYY (e.g. "Feb 15, 2026")
    final numericPatterns = [
      (RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})'), false),
      (RegExp(r'(\d{4})[/\-.](\d{2})[/\-.](\d{2})'), true),
      (RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2})\b'), false),
    ];

    for (final (pattern, yearFirst) in numericPatterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      try {
        int year, month, day;
        if (yearFirst) {
          year = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          day = int.parse(match.group(3)!);
        } else {
          day = int.parse(match.group(1)!);
          month = int.parse(match.group(2)!);
          year = int.parse(match.group(3)!);
          if (year < 100) year += 2000;
        }
        if (month < 1 || month > 12 || day < 1 || day > 31) continue;
        return DateTime(year, month, day);
      } catch (_) {
        continue;
      }
    }

    // Text-month patterns
    final textPatterns = [
      RegExp(r'(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})', caseSensitive: false),
      RegExp(r'([A-Za-z]+)\s+(\d{1,2})[,\s]+(\d{4})', caseSensitive: false),
    ];

    for (final pattern in textPatterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      try {
        int day, month, year;
        final g1 = match.group(1)!;
        final g2 = match.group(2)!;
        final g3 = match.group(3)!;
        if (_monthNames.containsKey(g2.toLowerCase())) {
          // DD MMM YYYY
          day = int.parse(g1);
          month = _monthNames[g2.toLowerCase()]!;
          year = int.parse(g3);
        } else if (_monthNames.containsKey(g1.toLowerCase())) {
          // MMM DD YYYY
          month = _monthNames[g1.toLowerCase()]!;
          day = int.parse(g2);
          year = int.parse(g3);
        } else {
          continue;
        }
        if (day < 1 || day > 31) continue;
        return DateTime(year, month, day);
      } catch (_) {
        continue;
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
