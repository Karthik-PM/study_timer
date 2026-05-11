import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/subject_tag.dart';
import '../models/study_session.dart';
import '../services/database_service.dart';
import 'sessions_provider.dart';

enum TimerStatus { idle, running, paused }

class TimerState {
  final TimerStatus status;
  final int elapsedSeconds;
  final SubjectTag? selectedTag;
  final DateTime? startTime;

  const TimerState({
    this.status = TimerStatus.idle,
    this.elapsedSeconds = 0,
    this.selectedTag,
    this.startTime,
  });

  TimerState copyWith({
    TimerStatus? status,
    int? elapsedSeconds,
    SubjectTag? selectedTag,
    DateTime? startTime,
    bool clearTag = false,
    bool clearStart = false,
  }) {
    return TimerState(
      status: status ?? this.status,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      selectedTag: clearTag ? null : (selectedTag ?? this.selectedTag),
      startTime: clearStart ? null : (startTime ?? this.startTime),
    );
  }

  String get formattedTime {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  final Ref _ref;
  Timer? _ticker;
  static const _uuid = Uuid();

  TimerNotifier(this._ref) : super(const TimerState());

  void selectTag(SubjectTag tag) {
    state = state.copyWith(selectedTag: tag);
  }

  void start() {
    if (state.selectedTag == null) return;
    final now = DateTime.now();
    state = state.copyWith(
      status: TimerStatus.running,
      startTime: state.startTime ?? now,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void pause() {
    _ticker?.cancel();
    state = state.copyWith(status: TimerStatus.paused);
  }

  void resume() {
    state = state.copyWith(status: TimerStatus.running);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  Future<StudySession?> stop() async {
    if (state.elapsedSeconds == 0 || state.selectedTag == null) {
      reset();
      return null;
    }
    _ticker?.cancel();
    final tag = state.selectedTag!;
    final now = DateTime.now();
    final session = StudySession(
      id: _uuid.v4(),
      tagId: tag.id,
      tagName: tag.name,
      tagColor: tag.colorValue,
      tagEmoji: tag.emoji,
      startTime: state.startTime ?? now.subtract(Duration(seconds: state.elapsedSeconds)),
      endTime: now,
      durationSeconds: state.elapsedSeconds,
    );
    await DatabaseService.insertSession(session);
    _ref.read(sessionsProvider.notifier).reload();
    reset();
    return session;
  }

  void reset() {
    _ticker?.cancel();
    state = const TimerState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>(
  (ref) => TimerNotifier(ref),
);
