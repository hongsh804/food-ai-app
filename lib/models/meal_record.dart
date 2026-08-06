import 'meal_analysis.dart';

class MealRecord {
  MealRecord({
    required this.id,
    required this.analysis,
    required this.analyzedAt,
  });

  factory MealRecord.create(MealAnalysis analysis) {
    final now = DateTime.now();
    return MealRecord(
      id: now.microsecondsSinceEpoch.toString(),
      analysis: analysis,
      analyzedAt: now,
    );
  }

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    return MealRecord(
      id: json['id'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
      analysis: MealAnalysis.fromJson(json['analysis'] as Map<String, dynamic>),
    );
  }

  final String id;
  final MealAnalysis analysis;
  final DateTime analyzedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'analyzedAt': analyzedAt.toIso8601String(),
      'analysis': analysis.toJson(),
    };
  }

  String get dayKey {
    final local = analyzedAt.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
  }

  String get dayLabel {
    final local = analyzedAt.toLocal();
    final today = _dateOnly(DateTime.now());
    final recordDate = _dateOnly(local);
    final difference = today.difference(recordDate).inDays;

    if (difference == 0) return '오늘';
    if (difference == 1) return '어제';
    return '${local.year}.${_twoDigits(local.month)}.${_twoDigits(local.day)}';
  }

  String get timeLabel {
    final local = analyzedAt.toLocal();
    return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String get dateTimeLabel => '$dayLabel $timeLabel';

  static DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}
