import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_analysis.dart';
import '../models/meal_record.dart';

class MealHistoryStore extends ChangeNotifier {
  MealHistoryStore._();

  static final MealHistoryStore instance = MealHistoryStore._();
  static const _storageKey = 'meal_history_records_v1';
  static const _sampleSeedKey = 'meal_history_sample_seeded_v1';

  final List<MealRecord> _records = [];
  bool _isLoaded = false;
  bool _demoSeedEnabled = true;

  bool get isLoaded => _isLoaded;

  List<MealRecord> get records => List.unmodifiable(_records);

  List<MealRecord> recentRecords({int limit = 2}) {
    return _records.take(limit).toList(growable: false);
  }

  Future<void> load() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final encodedRecords = prefs.getStringList(_storageKey) ?? const [];

    _records
      ..clear()
      ..addAll(
        encodedRecords
            .map(_decodeRecord)
            .whereType<MealRecord>()
            .toList(growable: false),
      );

    final shouldSeedDemoRecords =
        _demoSeedEnabled && (prefs.getBool(_sampleSeedKey) ?? false) == false;
    if (shouldSeedDemoRecords) {
      _records.addAll(_buildSampleWeekRecords());
      await prefs.setBool(_sampleSeedKey, true);
      await _save();
    }

    _records.sort(_latestFirst);

    _isLoaded = true;
    notifyListeners();
  }

  Future<MealRecord> addAnalysis(
    MealAnalysis analysis, {
    Uint8List? previewImageBytes,
  }) async {
    await load();

    final record = MealRecord.create(
      analysis,
      previewImageBytes: previewImageBytes,
    );
    _records.insert(0, record);
    await _save();
    notifyListeners();

    return record;
  }

  Future<void> deleteRecord(String id) async {
    await load();

    _records.removeWhere((record) => record.id == id);
    await _save();
    notifyListeners();
  }

  Map<String, List<MealRecord>> groupedRecords({String? dayKey}) {
    final grouped = <String, List<MealRecord>>{};

    for (final record in _records) {
      if (dayKey != null && record.dayKey != dayKey) continue;
      grouped.putIfAbsent(record.dayKey, () => []).add(record);
    }

    return grouped;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedRecords = _records
        .map((record) => jsonEncode(record.toJson()))
        .toList(growable: false);

    await prefs.setStringList(_storageKey, encodedRecords);
  }

  MealRecord? _decodeRecord(String encodedRecord) {
    try {
      final decoded = jsonDecode(encodedRecord);
      if (decoded is! Map<String, dynamic>) return null;
      return MealRecord.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  int _latestFirst(MealRecord left, MealRecord right) {
    return right.analyzedAt.compareTo(left.analyzedAt);
  }

  List<MealRecord> _buildSampleWeekRecords() {
    return [
      _sampleRecord(
        daysAgo: 0,
        hour: 8,
        minute: 20,
        analysis: const MealAnalysis(
          foodName: '그릭요거트 그래놀라',
          dateLabel: '오늘 아침',
          mealBurdenScore: 48,
          calories: 360,
          carbs: 44,
          protein: 18,
          fat: 11,
          sugar: 18,
          mealBurdenLevel: MealBurdenLevel.medium,
          mealBurdenDescription:
              '그래놀라와 과일의 당류를 고려해 식사 부담이 보통으로 분류됐습니다. 요거트 단백질을 함께 먹는 구성이에요.',
        ),
      ),
      _sampleRecord(
        daysAgo: 1,
        hour: 12,
        minute: 35,
        analysis: const MealAnalysis(
          foodName: '비빔밥',
          dateLabel: '어제 점심',
          mealBurdenScore: 66,
          calories: 650,
          carbs: 88,
          protein: 24,
          fat: 18,
          sugar: 12,
          mealBurdenLevel: MealBurdenLevel.medium,
          mealBurdenDescription:
              '밥의 추정 분량이 식사 부담에 큰 영향을 줍니다. 채소와 계란을 먼저 먹고 밥 양을 조금 줄여보세요.',
        ),
      ),
      _sampleRecord(
        daysAgo: 2,
        hour: 19,
        minute: 10,
        analysis: const MealAnalysis(
          foodName: '떡볶이와 김밥',
          dateLabel: '2일 전 저녁',
          mealBurdenScore: 94,
          calories: 920,
          carbs: 142,
          protein: 22,
          fat: 26,
          sugar: 28,
          mealBurdenLevel: MealBurdenLevel.high,
          mealBurdenDescription:
              '떡과 김밥의 정제 탄수화물이 겹치고 추정 분량도 커 식사 부담이 높게 분류됐습니다. 양을 조절하고 식후 걸어보세요.',
        ),
      ),
      _sampleRecord(
        daysAgo: 3,
        hour: 13,
        minute: 5,
        analysis: const MealAnalysis(
          foodName: '연어 아보카도 샐러드',
          dateLabel: '3일 전 점심',
          mealBurdenScore: 24,
          calories: 520,
          carbs: 22,
          protein: 34,
          fat: 32,
          sugar: 7,
          mealBurdenLevel: MealBurdenLevel.low,
          mealBurdenDescription: '탄수화물 비중이 낮고 단백질과 지방이 충분해 식사 부담이 낮게 분류됐습니다.',
        ),
      ),
      _sampleRecord(
        daysAgo: 4,
        hour: 20,
        minute: 15,
        analysis: MealAnalysis.demoResult.copyWith(dateLabel: '4일 전 저녁'),
      ),
      _sampleRecord(
        daysAgo: 5,
        hour: 12,
        minute: 0,
        analysis: const MealAnalysis(
          foodName: '현미 닭가슴살 도시락',
          dateLabel: '5일 전 점심',
          mealBurdenScore: 36,
          calories: 540,
          carbs: 58,
          protein: 42,
          fat: 13,
          sugar: 6,
          mealBurdenLevel: MealBurdenLevel.low,
          mealBurdenDescription:
              '현미와 단백질 조합이라 식사 부담이 낮게 분류됐습니다. 다만 밥 양이 많으면 부담이 커질 수 있어요.',
        ),
      ),
      _sampleRecord(
        daysAgo: 6,
        hour: 18,
        minute: 40,
        analysis: const MealAnalysis(
          foodName: '토마토 파스타',
          dateLabel: '6일 전 저녁',
          mealBurdenScore: 72,
          calories: 710,
          carbs: 96,
          protein: 24,
          fat: 22,
          sugar: 11,
          mealBurdenLevel: MealBurdenLevel.high,
          mealBurdenDescription:
              '면 중심이고 추정 분량이 커 식사 부담이 높게 분류됐습니다. 샐러드나 단백질을 먼저 먹고 면 양을 조절해보세요.',
        ),
      ),
      _sampleRecord(
        daysAgo: 7,
        hour: 12,
        minute: 25,
        analysis: const MealAnalysis(
          foodName: '카레라이스',
          dateLabel: '7일 전 점심',
          mealBurdenScore: 82,
          calories: 760,
          carbs: 108,
          protein: 22,
          fat: 24,
          sugar: 15,
          mealBurdenLevel: MealBurdenLevel.high,
          mealBurdenDescription:
              '흰쌀밥과 카레 소스의 탄수화물 비중과 추정 분량이 커 식사 부담이 높게 분류됐습니다. 밥 양을 줄여보세요.',
        ),
      ),
    ];
  }

  MealRecord _sampleRecord({
    required int daysAgo,
    required int hour,
    required int minute,
    required MealAnalysis analysis,
  }) {
    final day = _today().subtract(Duration(days: daysAgo));
    final analyzedAt = DateTime(day.year, day.month, day.day, hour, minute);

    return MealRecord(
      id: 'sample-${analyzedAt.microsecondsSinceEpoch}',
      analysis: analysis,
      analyzedAt: analyzedAt,
    );
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _records.clear();
    _isLoaded = false;
    notifyListeners();
  }

  @visibleForTesting
  void setDemoSeedEnabled(bool enabled) {
    _demoSeedEnabled = enabled;
  }
}
