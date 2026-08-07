import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_ai_app/models/meal_analysis.dart';
import 'package:food_ai_app/screens/result_screen.dart';

void main() {
  test('보정 메타데이터를 분석 응답에서 읽고 기록에 보존한다', () {
    final analysis = MealAnalysis.fromJson({
      'foodName': '김밥',
      'dateLabel': '오늘 식사',
      'glucoseSpikeScore': 100,
      'estimatedGlucoseRise': 80,
      'estimatedPeakMinutes': 60,
      'calories': 520,
      'carbs': 75,
      'protein': 16,
      'fat': 14,
      'sugar': 7,
      'glucoseRisk': 'high',
      'glucoseDescription': '측정 자료 기반 보정 예시',
      'calibration': {
        'applied': true,
        'ruleId': 'menu-gimbap',
        'ruleName': '김밥',
        'matchType': 'menu',
        'mode': 'delta',
        'rawEstimatedGlucoseRise': 60,
        'adjustedEstimatedGlucoseRise': 80,
        'sampleCount': 5,
        'note': '동일 분량 반복 측정 5건 기준',
      },
    });

    expect(analysis.calibration?.applied, isTrue);
    expect(analysis.calibration?.rawEstimatedGlucoseRise, 60);
    expect(analysis.calibration?.adjustedEstimatedGlucoseRise, 80);
    expect(analysis.calibration?.matchType, 'menu');

    final restored = MealAnalysis.fromJson(analysis.toJson());
    expect(restored.calibration?.ruleId, 'menu-gimbap');
    expect(restored.calibration?.sampleCount, 5);
    expect(restored.estimatedGlucoseRise, 80);
  });

  test('보정 메타데이터가 없는 기존 기록도 계속 읽을 수 있다', () {
    final analysis = MealAnalysis.fromJson({
      'foodName': '샐러드',
      'glucoseRisk': 'low',
    });

    expect(analysis.calibration, isNull);
  });

  testWidgets('선택한 보정이 거부되면 결과 화면에 이유를 표시한다', (tester) async {
    final analysis = MealAnalysis.fromJson({
      'foodName': '김밥',
      'glucoseRisk': 'medium',
      'calibration': {
        'applied': false,
        'rawEstimatedGlucoseRise': 34,
        'adjustedEstimatedGlucoseRise': 34,
        'note': '요청한 보정 프로필이 없거나 비활성 상태입니다.',
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(analysis: analysis, showActionButtons: false),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('선택한 보정이 적용되지 않았어요'), findsOneWidget);
    expect(find.textContaining('없거나 비활성'), findsOneWidget);
  });
}
