class StudySession {
  final String id;
  final String tagId;
  final String tagName;
  final int tagColor;
  final String tagEmoji;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final String notes;

  const StudySession({
    required this.id,
    required this.tagId,
    required this.tagName,
    required this.tagColor,
    required this.tagEmoji,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    this.notes = '',
  });

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'tagId': tagId,
        'tagName': tagName,
        'tagColor': tagColor,
        'tagEmoji': tagEmoji,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'durationSeconds': durationSeconds,
        'notes': notes,
      };

  factory StudySession.fromMap(Map<String, dynamic> map) => StudySession(
        id: map['id'] as String,
        tagId: map['tagId'] as String,
        tagName: map['tagName'] as String,
        tagColor: map['tagColor'] as int,
        tagEmoji: map['tagEmoji'] as String? ?? '📚',
        startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
        endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
        durationSeconds: map['durationSeconds'] as int,
        notes: map['notes'] as String? ?? '',
      );
}
