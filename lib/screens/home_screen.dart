import 'package:flutter/material.dart';

import '../models/meal_record.dart';
import '../services/meal_history_store.dart';
import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';
import 'result_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onCapture,
    required this.onOpenHistory,
    required this.onOpenInsights,
  });

  final VoidCallback onCapture;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenInsights;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: MealHistoryStore.instance,
        builder: (context, _) {
          final records = MealHistoryStore.instance.records;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 118),
            children: [
              const _HomeHeader(),
              const SizedBox(height: 26),
              Text(
                _greeting(),
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  height: 1.35,
                  letterSpacing: -.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 17),
              _PredictionHero(
                latest: records.isEmpty ? null : records.first,
                onTap: records.isEmpty
                    ? onCapture
                    : () => _openResult(context, records.first),
              ),
              const SizedBox(height: 16),
              _TodaySummary(records: records),
              const SizedBox(height: 20),
              SectionTitle(
                title: '최근 기록',
                action: '더보기',
                onAction: onOpenHistory,
              ),
              const SizedBox(height: 4),
              if (records.isEmpty)
                _EmptyRecent(onCapture: onCapture)
              else
                for (final record in records.take(2)) ...[
                  _RecentMealTile(
                    record: record,
                    onTap: () => _openResult(context, record),
                  ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 12),
              _CoachCard(onTap: onOpenInsights),
            ],
          );
        },
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final firstLine = hour < 11
        ? '좋은 아침이에요'
        : hour < 17
        ? '건강한 오후예요'
        : '오늘도 수고했어요';
    return '$firstLine,\n식사 균형을 확인해볼까요? 💚';
  }

  void _openResult(BuildContext context, MealRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ResultScreen(analysis: record.analysis, showActionButtons: false),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Gluco'),
              TextSpan(
                text: 'Log',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 26,
            letterSpacing: -0.8,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.ink,
            size: 23,
          ),
        ),
      ],
    );
  }
}

class _PredictionHero extends StatelessWidget {
  const _PredictionHero({required this.latest, required this.onTap});

  final MealRecord? latest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final analysis = latest?.analysis;
    final rise = analysis?.estimatedGlucoseRise ?? 0;
    final values = analysis == null
        ? const [18.0, 24.0, 35.0, 52.0, 34.0, 22.0]
        : [10.0, rise * .4, rise * .8, rise.toDouble(), rise * .62, rise * .3];

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 19, 17, 16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3212B9A1),
              blurRadius: 22,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  analysis == null ? '첫 식사를 기록해보세요' : '최근 식사 AI 예측',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    analysis?.glucoseRisk.label ?? '분석하기',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (analysis != null)
                        Text(
                          analysis.foodName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xDDFFFFFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: analysis == null ? '--' : '+$rise'),
                            const TextSpan(
                              text: ' mg/dL',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 39,
                          letterSpacing: -1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        '예상 식후 혈당 상승폭',
                        style: TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TrendChart(values: values, height: 74),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .17),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                analysis == null
                    ? '카메라 버튼을 눌러 시작하세요'
                    : '${analysis.estimatedPeakMinutes}분 전후 피크 · AI 추정값',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.records});

  final List<MealRecord> records;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = records.where((record) {
      final date = record.analyzedAt.toLocal();
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
    final calories = today.fold<int>(
      0,
      (sum, item) => sum + item.analysis.calories,
    );
    final carbs = today.fold<int>(0, (sum, item) => sum + item.analysis.carbs);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘의 요약',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${now.month}.${now.day.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.grain_rounded,
                  color: AppColors.medium,
                  label: '탄수화물',
                  value: '$carbs g',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF9F43),
                  label: '칼로리',
                  value: '$calories kcal',
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.restaurant_rounded,
                  color: AppColors.primary,
                  label: '기록 식사',
                  value: '${today.length}회',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .11),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentMealTile extends StatelessWidget {
  const _RecentMealTile({required this.record, required this.onTap});

  final MealRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: .16),
                  AppColors.mint.withValues(alpha: .07),
                ],
              ),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.analysis.foodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  record.dateTimeLabel,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${record.analysis.estimatedGlucoseRise}',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'mg/dL 예상',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent({required this.onCapture});

  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onCapture,
      child: const Row(
        children: [
          Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(child: Text('아직 기록이 없어요. 첫 식사를 촬영해보세요.')),
          Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceWarm,
      onTap: onTap,
      child: const Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primaryDark,
            ),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 식사 코칭',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '최근 식사 흐름과 맞춤 팁을 확인해보세요.',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark),
        ],
      ),
    );
  }
}
