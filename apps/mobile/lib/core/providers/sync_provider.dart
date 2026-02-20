import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  // TODO: Wire up to SyncServiceImpl
  yield SyncStatus.idle;
});
