import 'package:equatable/equatable.dart';

class ReceiptModel extends Equatable {
  final String receiptId;
  final String uid;
  final String storagePath;
  final String? txnId;
  final DateTime uploadedAt;
  final int fileSizeBytes;
  final String mimeType;

  const ReceiptModel({
    required this.receiptId,
    required this.uid,
    required this.storagePath,
    this.txnId,
    required this.uploadedAt,
    required this.fileSizeBytes,
    required this.mimeType,
  });

  ReceiptModel copyWith({
    String? receiptId,
    String? uid,
    String? storagePath,
    String? txnId,
    DateTime? uploadedAt,
    int? fileSizeBytes,
    String? mimeType,
  }) {
    return ReceiptModel(
      receiptId: receiptId ?? this.receiptId,
      uid: uid ?? this.uid,
      storagePath: storagePath ?? this.storagePath,
      txnId: txnId ?? this.txnId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'receiptId': receiptId,
      'uid': uid,
      'storagePath': storagePath,
      'txnId': txnId,
      'uploadedAt': uploadedAt.toIso8601String(),
      'fileSizeBytes': fileSizeBytes,
      'mimeType': mimeType,
    };
  }

  factory ReceiptModel.fromMap(Map<String, dynamic> map) {
    return ReceiptModel(
      receiptId: map['receiptId'] as String,
      uid: map['uid'] as String,
      storagePath: map['storagePath'] as String,
      txnId: map['txnId'] as String?,
      uploadedAt: DateTime.parse(map['uploadedAt'] as String),
      fileSizeBytes: map['fileSizeBytes'] as int,
      mimeType: map['mimeType'] as String,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory ReceiptModel.fromJson(Map<String, dynamic> json) =>
      ReceiptModel.fromMap(json);

  @override
  List<Object?> get props => [
        receiptId,
        uid,
        storagePath,
        txnId,
        uploadedAt,
        fileSizeBytes,
        mimeType,
      ];
}
