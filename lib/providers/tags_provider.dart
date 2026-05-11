import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject_tag.dart';
import '../services/database_service.dart';

class TagsNotifier extends StateNotifier<AsyncValue<List<SubjectTag>>> {
  TagsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = await AsyncValue.guard(DatabaseService.getTags);
  }

  Future<void> add(SubjectTag tag) async {
    await DatabaseService.insertTag(tag);
    load();
  }

  Future<void> update(SubjectTag tag) async {
    await DatabaseService.updateTag(tag);
    load();
  }

  Future<void> delete(String id) async {
    await DatabaseService.deleteTag(id);
    load();
  }
}

final tagsProvider =
    StateNotifierProvider<TagsNotifier, AsyncValue<List<SubjectTag>>>(
  (ref) => TagsNotifier(),
);
