import 'package:flutter/material.dart';

class SubjectTag {
  final String id;
  final String name;
  final int colorValue;
  final String emoji;

  const SubjectTag({
    required this.id,
    required this.name,
    required this.colorValue,
    this.emoji = '📚',
  });

  Color get color => Color(colorValue);

  SubjectTag copyWith({String? id, String? name, int? colorValue, String? emoji}) {
    return SubjectTag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      emoji: emoji ?? this.emoji,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'emoji': emoji,
      };

  factory SubjectTag.fromMap(Map<String, dynamic> map) => SubjectTag(
        id: map['id'] as String,
        name: map['name'] as String,
        colorValue: map['colorValue'] as int,
        emoji: map['emoji'] as String? ?? '📚',
      );

  static final List<SubjectTag> defaults = [
    SubjectTag(id: 'math', name: 'Math', colorValue: Colors.blue.toARGB32(), emoji: '📐'),
    SubjectTag(id: 'science', name: 'Science', colorValue: Colors.green.toARGB32(), emoji: '🔬'),
    SubjectTag(id: 'language', name: 'Language', colorValue: Colors.purple.toARGB32(), emoji: '📝'),
    SubjectTag(id: 'history', name: 'History', colorValue: Colors.orange.toARGB32(), emoji: '🏛️'),
    SubjectTag(id: 'coding', name: 'Coding', colorValue: Colors.teal.toARGB32(), emoji: '💻'),
  ];
}
