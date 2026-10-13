import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:food_ai_app/main.dart' as app;

void main() {
  testWidgets('LOW42 쇼핑과 마이 멤버십 동선이 동작한다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding_v2': true,
      'meal_history_sample_seeded_v1': true,
    });

    await app.main();
    await tester.pumpAndSettle();

    expect(find.text('LOW42'), findsOneWidget);
    expect(find.text('쇼핑'), findsOneWidget);
    expect(find.text('사진으로 식사 부담 확인'), findsOneWidget);

    await tester.tap(find.text('쇼핑'));
    await tester.pumpAndSettle();
    expect(find.text('LOW42 쇼핑'), findsOneWidget);
    expect(find.text('LOW42 저당 밀가루'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('LOW42 멤버십'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('LOW42 멤버십'));
    await tester.pumpAndSettle();
    expect(find.text('마이'), findsOneWidget);
    expect(find.text('LOW42 방문 멤버십'), findsOneWidget);
    expect(find.text('시안용 도장 추가'), findsOneWidget);

    await tester.tap(find.text('시안용 도장 추가'));
    await tester.pumpAndSettle();
    expect(find.text('방문 도장 추가'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '시안용 도장 추가'));
    await tester.pumpAndSettle();
    expect(find.text('누적 1회'), findsOneWidget);
  });
}
