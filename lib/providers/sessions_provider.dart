import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/study_session.dart';
import '../services/database_service.dart';

class SessionsNotifier extends StateNotifier<AsyncValue<List<StudySession>>> {
  SessionsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({String? tagId}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => DatabaseService.getSessions(tagId: tagId));
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() => DatabaseService.getSessions());
  }

  Future<void> delete(String id) async {
    await DatabaseService.deleteSession(id);
    reload();
  }
}

final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, AsyncValue<List<StudySession>>>(
  (ref) => SessionsNotifier(),
);
