import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../providers/analytics_provider.dart';

class AdminFirebaseService {
  final FirebaseFirestore _firestore;

  AdminFirebaseService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<UserModel>> getAllUsers({int limit = 100}) async {
    final snapshot = await _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .toList();
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<List<TransactionModel>> getUserTransactions(
    String uid, {
    int limit = 50,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data()))
        .toList();
  }

  Future<List<TransactionModel>> getOpenFlags({int limit = 50}) async {
    // Query admin_flags collection for open items
    final snapshot = await _firestore
        .collection('admin_flags')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data()))
        .toList();
  }

  Stream<List<TransactionModel>> streamOpenFlags({int limit = 50}) {
    return _firestore
        .collection('admin_flags')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => TransactionModel.fromMap(doc.data())).toList());
  }

  Future<String?> getReceiptDownloadUrl(String storagePath) async {
    // Support legacy receipts that stored a download URL directly.
    if (storagePath.startsWith('https://')) return storagePath;
    try {
      return await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserPlan(String uid, String plan) async {
    await _firestore.collection('users').doc(uid).update({'plan': plan});
  }

  Future<void> resolveFlag(String flagId, String resolution) async {
    // Look up the uid stored in the flag so we can clear flaggedForReview
    // on the user's own transaction document.
    final flagDoc =
        await _firestore.collection('admin_flags').doc(flagId).get();
    final uid = flagDoc.data()?['uid'] as String?;

    final batch = _firestore.batch();
    batch.update(_firestore.collection('admin_flags').doc(flagId), {
      'status': resolution,
      'resolvedAt': DateTime.now().toIso8601String(),
    });
    if (uid != null) {
      batch.update(
        _firestore
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .doc(flagId),
        {
          'flaggedForReview': false,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );
    }
    await batch.commit();
  }

  /// Applies admin corrections to a flagged transaction. The [updates] map
  /// is merged into both the user's transaction doc and the admin_flags doc,
  /// and the flag is resolved as 'corrected'.
  Future<void> correctTransaction(
    String flagId,
    Map<String, dynamic> updates,
  ) async {
    final flagDoc =
        await _firestore.collection('admin_flags').doc(flagId).get();
    final uid = flagDoc.data()?['uid'] as String?;

    final now = DateTime.now().toIso8601String();
    final batch = _firestore.batch();

    // Resolve the admin flag
    batch.update(_firestore.collection('admin_flags').doc(flagId), {
      ...updates,
      'status': 'corrected',
      'resolvedAt': now,
    });

    if (uid != null) {
      batch.update(
        _firestore
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .doc(flagId),
        {
          ...updates,
          'flaggedForReview': false,
          'updatedAt': now,
        },
      );
    }
    await batch.commit();
  }

  Future<DashboardKpis> getDashboardKpis() async {
    // Run aggregation queries in parallel
    final results = await Future.wait([
      _firestore.collection('users').count().get(),
      _firestore
          .collection('users')
          .where('plan', whereIn: ['pro', 'business'])
          .count()
          .get(),
      _firestore
          .collection('admin_flags')
          .where('status', isEqualTo: 'open')
          .count()
          .get(),
    ]);

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    // receiptsScannedToday requires a collectionGroup query
    final todaySnap = await _firestore
        .collectionGroup('transactions')
        .where('source', isEqualTo: 'ocr')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .count()
        .get();

    return DashboardKpis(
      totalUsers: results[0].count ?? 0,
      activeSubscriptions: results[1].count ?? 0,
      receiptsScannedToday: todaySnap.count ?? 0,
      openOcrFlags: results[2].count ?? 0,
    );
  }
}
