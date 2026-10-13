import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_ai_app/models/meal_analysis.dart';
import 'package:food_ai_app/models/meal_record.dart';
import 'package:food_ai_app/services/membership_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('촬영 사진 미리보기를 식사 기록 JSON에 보존한다', () {
    final preview = Uint8List.fromList([1, 2, 3, 4, 5]);
    final record = MealRecord.create(
      MealAnalysis.demoResult,
      previewImageBytes: preview,
    );

    final restored = MealRecord.fromJson(record.toJson());

    expect(restored.previewImageBytes, preview);
    expect(restored.analysis.foodName, record.analysis.foodName);
  });

  test('10번째 방문에서 무료 샐러드 쿠폰을 발급한다', () async {
    SharedPreferences.setMockInitialValues({});
    await MembershipStore.instance.resetForTest();

    for (var index = 0; index < 9; index += 1) {
      expect(await MembershipStore.instance.addVisitStamp(), isFalse);
    }
    expect(MembershipStore.instance.stampProgress, 9);

    expect(await MembershipStore.instance.addVisitStamp(), isTrue);
    expect(MembershipStore.instance.totalVisits, 10);
    expect(MembershipStore.instance.stampProgress, 0);
    expect(MembershipStore.instance.saladCoupons, 1);

    expect(await MembershipStore.instance.redeemSaladCoupon(), isTrue);
    expect(MembershipStore.instance.saladCoupons, 0);
  });
}
