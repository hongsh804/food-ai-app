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

  Future<MealRecord> addAnalysis(MealAnalysis analysis) async {
    await load();

    final record = MealRecord.create(analysis);
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
          glucoseSpikeScore: 48,
          estimatedGlucoseRise: 27,
          estimatedPeakMinutes: 55,
          calories: 360,
          carbs: 44,
          protein: 18,
          fat: 11,
          sugar: 18,
          glucoseRisk: GlucoseRisk.medium,
          glucoseDescription:
              '그래놀라와 과일의 당류가 있어 혈당이 중간 정도 오를 수 있어요. 요거트 단백질이 상승 속도를 일부 완만하게 만듭니다.',
        ),
      ),
      _sampleRecord(
        daysAgo: 1,
        hour: 12,
        minute: 35,
        analysis: const MealAnalysis(
          foodName: '비빔밥',
          dateLabel: '어제 점심',
          glucoseSpikeScore: 66,
          estimatedGlucoseRise: 38,
          estimatedPeakMinutes: 70,
          calories: 650,
          carbs: 88,
          protein: 24,
          fat: 18,
          sugar: 12,
          glucoseRisk: GlucoseRisk.medium,
          glucoseDescription:
              '밥 양이 혈당 반응을 크게 좌우합니다. 채소와 계란을 먼저 먹고 밥을 조금 남기면 스파이크 부담을 줄일 수 있어요.',
        ),
      ),
      _sampleRecord(
        daysAgo: 2,
        hour: 19,
        minute: 10,
        analysis: const MealAnalysis(
          foodName: '떡볶이와 김밥',
          dateLabel: '2일 전 저녁',
          glucoseSpikeScore: 94,
          estimatedGlucoseRise: 68,
          estimatedPeakMinutes: 45,
          calories: 920,
          carbs: 142,
          protein: 22,
          fat: 26,
          sugar: 28,
          glucoseRisk: GlucoseRisk.high,
          glucoseDescription:
              '떡과 김밥의 정제 탄수화물이 겹쳐 식후 혈당이 빠르게 오를 가능성이 큽니다. 양 조절과 식후 걷기가 특히 중요해요.',
        ),
      ),
      _sampleRecord(
        daysAgo: 3,
        hour: 13,
        minute: 5,
        analysis: const MealAnalysis(
          foodName: '연어 아보카도 샐러드',
          dateLabel: '3일 전 점심',
          glucoseSpikeScore: 24,
          estimatedGlucoseRise: 14,
          estimatedPeakMinutes: 95,
          calories: 520,
          carbs: 22,
          protein: 34,
          fat: 32,
          sugar: 7,
          glucoseRisk: GlucoseRisk.low,
          glucoseDescription: '탄수화물 비중이 낮고 단백질과 지방이 충분해 혈당 상승은 완만할 것으로 예상됩니다.',
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
          glucoseSpikeScore: 36,
          estimatedGlucoseRise: 21,
          estimatedPeakMinutes: 85,
          calories: 540,
          carbs: 58,
          protein: 42,
          fat: 13,
          sugar: 6,
          glucoseRisk: GlucoseRisk.low,
          glucoseDescription:
              '현미와 단백질 조합이라 혈당 상승은 비교적 완만할 것으로 예상됩니다. 다만 밥 양이 많으면 상승폭이 커질 수 있어요.',
        ),
      ),
      _sampleRecord(
        daysAgo: 6,
        hour: 18,
        minute: 40,
        analysis: const MealAnalysis(
          foodName: '토마토 파스타',
          dateLabel: '6일 전 저녁',
          glucoseSpikeScore: 72,
          estimatedGlucoseRise: 43,
          estimatedPeakMinutes: 65,
          calories: 710,
          carbs: 96,
          protein: 24,
          fat: 22,
          sugar: 11,
          glucoseRisk: GlucoseRisk.high,
          glucoseDescription:
              '면 중심 식사라 혈당 스파이크 가능성이 높습니다. 샐러드나 단백질을 먼저 먹으면 피크를 낮추는 데 도움이 됩니다.',
        ),
      ),
      _sampleRecord(
        daysAgo: 7,
        hour: 12,
        minute: 25,
        analysis: const MealAnalysis(
          foodName: '카레라이스',
          dateLabel: '7일 전 점심',
          glucoseSpikeScore: 82,
          estimatedGlucoseRise: 50,
          estimatedPeakMinutes: 60,
          calories: 760,
          carbs: 108,
          protein: 22,
          fat: 24,
          sugar: 15,
          glucoseRisk: GlucoseRisk.high,
          glucoseDescription:
              '흰쌀밥과 카레 소스의 탄수화물 비중이 높아 식후 혈당이 크게 오를 수 있어요. 밥 양을 줄이면 부담이 낮아집니다.',
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
