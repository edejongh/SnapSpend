import 'package:equatable/equatable.dart';

class TransactionModel extends Equatable {
  final String txnId;
  final double amount;
  final String currency;
  final double amountZAR;
  final String category;
  final String? subcategory;
  final String vendor;
  final DateTime date;
  final String? note;
  final String? receiptStoragePath;
  final bool isTaxDeductible;
  final String? ocrRawText;
  final double? ocrConfidence;
  final String source;
  final bool flaggedForReview;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.txnId,
    required this.amount,
    required this.currency,
    required this.amountZAR,
    required this.category,
    this.subcategory,
    required this.vendor,
    required this.date,
    this.note,
    this.receiptStoragePath,
    required this.isTaxDeductible,
    this.ocrRawText,
    this.ocrConfidence,
    required this.source,
    required this.flaggedForReview,
    required this.createdAt,
    required this.updatedAt,
  });

  TransactionModel copyWith({
    String? txnId,
    double? amount,
    String? currency,
    double? amountZAR,
    String? category,
    String? subcategory,
    String? vendor,
    DateTime? date,
    String? note,
    String? receiptStoragePath,
    bool? isTaxDeductible,
    String? ocrRawText,
    double? ocrConfidence,
    String? source,
    bool? flaggedForReview,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      txnId: txnId ?? this.txnId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      amountZAR: amountZAR ?? this.amountZAR,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      vendor: vendor ?? this.vendor,
      date: date ?? this.date,
      note: note ?? this.note,
      receiptStoragePath: receiptStoragePath ?? this.receiptStoragePath,
      isTaxDeductible: isTaxDeductible ?? this.isTaxDeductible,
      ocrRawText: ocrRawText ?? this.ocrRawText,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      source: source ?? this.source,
      flaggedForReview: flaggedForReview ?? this.flaggedForReview,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'txnId': txnId,
      'amount': amount,
      'currency': currency,
      'amountZAR': amountZAR,
      'category': category,
      'subcategory': subcategory,
      'vendor': vendor,
      'date': date.toIso8601String(),
      'note': note,
      'receiptStoragePath': receiptStoragePath,
      'isTaxDeductible': isTaxDeductible,
      'ocrRawText': ocrRawText,
      'ocrConfidence': ocrConfidence,
      'source': source,
      'flaggedForReview': flaggedForReview,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      txnId: map['txnId'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String,
      amountZAR: (map['amountZAR'] as num).toDouble(),
      category: map['category'] as String,
      subcategory: map['subcategory'] as String?,
      vendor: map['vendor'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      receiptStoragePath: map['receiptStoragePath'] as String?,
      isTaxDeductible: map['isTaxDeductible'] as bool,
      ocrRawText: map['ocrRawText'] as String?,
      ocrConfidence: map['ocrConfidence'] != null
          ? (map['ocrConfidence'] as num).toDouble()
          : null,
      source: map['source'] as String,
      flaggedForReview: map['flaggedForReview'] as bool,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory TransactionModel.fromJson(Map<String, dynamic> json) =>
      TransactionModel.fromMap(json);

  @override
  List<Object?> get props => [
        txnId,
        amount,
        currency,
        amountZAR,
        category,
        subcategory,
        vendor,
        date,
        note,
        receiptStoragePath,
        isTaxDeductible,
        ocrRawText,
        ocrConfidence,
        source,
        flaggedForReview,
        createdAt,
        updatedAt,
      ];
}
