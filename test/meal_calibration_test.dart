import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:food_ai_app/models/food_identification_result.dart';
import 'package:food_ai_app/models/meal_analysis.dart';
import 'package:food_ai_app/screens/result_screen.dart';

void main() {
  test('제품 가이드 메타데이터를 분석 응답에서 읽고 기록에 보존한다', () {
    final analysis = MealAnalysis.fromJson({
      'foodName': '김밥',
      'dateLabel': '오늘 식사',
      'mealBurdenScore': 80,
      'calories': 520,
      'carbs': 75,
      'protein': 16,
      'fat': 14,
      'sugar': 7,
      'mealBurdenLevel': 'high',
      'mealBurdenDescription': '등록 제품의 원재료와 영양 정보를 반영했습니다.',
      'calibration': {
        'applied': true,
        'ruleId': 'menu-gimbap',
        'ruleName': '김밥',
        'matchType': 'menu',
        'mode': 'delta',
        'rawMealBurdenScore': 60,
        'adjustedMealBurdenScore': 80,
        'sampleCount': 5,
        'note': '등록 제품 정보 5건 기준',
      },
    });

    expect(analysis.calibration?.applied, isTrue);
    expect(analysis.calibration?.rawMealBurdenScore, 60);
    expect(analysis.calibration?.adjustedMealBurdenScore, 80);
    expect(analysis.calibration?.matchType, 'menu');

    final restored = MealAnalysis.fromJson(analysis.toJson());
    expect(restored.calibration?.ruleId, 'menu-gimbap');
    expect(restored.calibration?.sampleCount, 5);
    expect(restored.mealBurdenScore, 80);
  });

  test('보정 메타데이터가 없는 기존 기록도 계속 읽을 수 있다', () {
    final analysis = MealAnalysis.fromJson({
      'foodName': '샐러드',
      'glucoseRisk': 'low',
    });

    expect(analysis.calibration, isNull);
  });

  test('기존 혈당 예측 기록은 중립적인 식사 부담 기록으로 마이그레이션한다', () {
    final analysis = MealAnalysis.fromJson({
      'foodName': '당뇨 개선 샐러드',
      'glucoseSpikeScore': 90,
      'glucoseRisk': 'high',
      'glucoseDescription': '예상 혈당 상승폭은 60 mg/dL입니다.',
      'portionDescription': '예상 혈당 피크 60분',
      'ingredients': [
        {'name': '혈당 치료 소스', 'amount': '혈당 -30 mg/dL', 'note': '당뇨 예방'},
      ],
    });

    expect(analysis.mealBurdenScore, 90);
    expect(analysis.mealBurdenLevel, MealBurdenLevel.high);
    expect(analysis.foodName, '확인한 음식');
    expect(analysis.portionDescription, '사진 기준 약 1인분 추정');
    expect(analysis.ingredients.single.name, '알 수 없는 재료');
    expect(analysis.ingredients.single.amount, '양 추정 어려움');
    expect(analysis.ingredients.single.note, '식사 구성 참고');
    expect(analysis.mealBurdenDescription, isNot(contains('혈당')));
    expect(analysis.toJson().containsKey('glucoseSpikeScore'), isFalse);
    expect(analysis.toJson().containsKey('estimatedGlucoseRise'), isFalse);
  });

  test('운영 제품 프로필의 의료성 동적 문구를 표시하지 않는다', () {
    final profile = CalibrationProfileSummary.fromJson({
      'id': 'unsafe-product',
      'name': '당뇨 치료 저당면',
      'description': '혈당 30 mg/dL 감소 예측',
      'sampleCount': 8,
    });

    expect(profile.name, isEmpty);
    expect(profile.description, isEmpty);
    expect(profile.sampleCount, 8);
  });

  testWidgets('선택한 보정이 거부되면 결과 화면에 이유를 표시한다', (tester) async {
    final analysis = MealAnalysis.fromJson({
      'foodName': '김밥',
      'mealBurdenLevel': 'medium',
      'calibration': {
        'applied': false,
        'rawMealBurdenScore': 54,
        'adjustedMealBurdenScore': 54,
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
