import 'dart:convert';
import 'dart:typed_data';

import 'meal_analysis.dart';

class MealRecord {
  MealRecord({
    required this.id,
    required this.analysis,
    required this.analyzedAt,
    this.previewImageBytes,
  });

  factory MealRecord.create(
    MealAnalysis analysis, {
    Uint8List? previewImageBytes,
  }) {
    final now = DateTime.now();
    return MealRecord(
      id: now.microsecondsSinceEpoch.toString(),
      analysis: analysis,
      analyzedAt: now,
      previewImageBytes: previewImageBytes,
    );
  }

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    return MealRecord(
      id: json['id'] as String,
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
      analysis: MealAnalysis.fromJson(json['analysis'] as Map<String, dynamic>),
      previewImageBytes: _decodePreview(json['previewImageBase64']),
    );
  }

  final String id;
  final MealAnalysis analysis;
  final DateTime analyzedAt;
  final Uint8List? previewImageBytes;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'analyzedAt': analyzedAt.toIso8601String(),
      'analysis': analysis.toJson(),
    };
    if (previewImageBytes case final bytes?) {
      json['previewImageBase64'] = base64Encode(bytes);
    }
    return json;
  }

  static Uint8List? _decodePreview(Object? encoded) {
    if (encoded is! String || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } on FormatException {
      return null;
    }
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
