import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MembershipStore extends ChangeNotifier {
  MembershipStore._();

  static final MembershipStore instance = MembershipStore._();

  static const int stampsPerReward = 10;
  static const _totalVisitsKey = 'low42_membership_total_visits_v1';
  static const _stampProgressKey = 'low42_membership_stamp_progress_v1';
  static const _saladCouponsKey = 'low42_membership_salad_coupons_v1';

  int _totalVisits = 0;
  int _stampProgress = 0;
  int _saladCoupons = 0;
  bool _loaded = false;

  int get totalVisits => _totalVisits;
  int get stampProgress => _stampProgress;
  int get saladCoupons => _saladCoupons;
  int get stampsUntilReward => stampsPerReward - _stampProgress;

  Future<void> load() async {
    if (_loaded) return;
    final preferences = await SharedPreferences.getInstance();
    _totalVisits = preferences.getInt(_totalVisitsKey) ?? 0;
    _stampProgress = (preferences.getInt(_stampProgressKey) ?? 0).clamp(
      0,
      stampsPerReward - 1,
    );
    _saladCoupons = preferences.getInt(_saladCouponsKey) ?? 0;
    _loaded = true;
    notifyListeners();
  }

  Future<bool> addVisitStamp() async {
    await load();
    _totalVisits += 1;
    _stampProgress += 1;
    final rewardCreated = _stampProgress >= stampsPerReward;
    if (rewardCreated) {
      _stampProgress = 0;
      _saladCoupons += 1;
    }
    await _save();
    notifyListeners();
    return rewardCreated;
  }

  Future<bool> redeemSaladCoupon() async {
    await load();
    if (_saladCoupons <= 0) return false;
    _saladCoupons -= 1;
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setInt(_totalVisitsKey, _totalVisits),
      preferences.setInt(_stampProgressKey, _stampProgress),
      preferences.setInt(_saladCouponsKey, _saladCoupons),
    ]);
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _totalVisits = 0;
    _stampProgress = 0;
    _saladCoupons = 0;
    _loaded = false;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(_totalVisitsKey),
      preferences.remove(_stampProgressKey),
      preferences.remove(_saladCouponsKey),
    ]);
    notifyListeners();
  }
}
