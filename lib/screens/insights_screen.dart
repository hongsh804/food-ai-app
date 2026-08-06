import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/meal_analysis.dart';
import '../models/meal_record.dart';
import '../services/meal_history_store.dart';
import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: MealHistoryStore.instance,
        builder: (context, _) {
          final records = MealHistoryStore.instance.records
              .take(7)
              .toList()
              .reversed
              .toList();
          final values = records.isEmpty
              ? const [18.0, 30.0, 24.0, 42.0, 20.0, 35.0, 27.0]
              : records
                    .map(
                      (record) =>
                          record.analysis.estimatedGlucoseRise.toDouble(),
                    )
                    .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 118),
            children: [
              const Text(
                '분석',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '최근 식사에서 혈당 부담 패턴을 찾아봤어요.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              _RangeSelector(),
              const SizedBox(height: 14),
              _TrendCard(records: records, values: values),
              const SizedBox(height: 14),
              _StatsCard(records: records),
              const SizedBox(height: 14),
              _CoachingCard(records: records),
              const SizedBox(height: 14),
              const _SafetyCard(),
            ],
          );
        },
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Text(
                '주',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '월',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '3개월',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.records, required this.values});

  final List<MealRecord> records;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final average = values.isEmpty
        ? 0
        : (values.reduce((a, b) => a + b) / values.length).round();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '평균 예상 상승폭',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '+$average',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'mg/dL',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const RiskPill(risk: GlucoseRisk.medium),
            ],
          ),
          const SizedBox(height: 18),
          TrendChart(
            values: values,
            height: 130,
            lineColor: AppColors.primaryDark,
            fillColor: AppColors.primary.withValues(alpha: .10),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('월', style: _axisStyle),
              Text('화', style: _axisStyle),
              Text('수', style: _axisStyle),
              Text('목', style: _axisStyle),
              Text('금', style: _axisStyle),
              Text('토', style: _axisStyle),
              Text('일', style: _axisStyle),
            ],
          ),
        ],
      ),
    );
  }
}

const _axisStyle = TextStyle(
  color: AppColors.muted,
  fontSize: 10,
  fontWeight: FontWeight.w600,
);

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.records});

  final List<MealRecord> records;

  @override
  Widget build(BuildContext context) {
    final rises = records
        .map((record) => record.analysis.estimatedGlucoseRise)
        .toList();
    final high = rises.isEmpty ? 0 : rises.reduce(math.max);
    final low = rises.isEmpty ? 0 : rises.reduce(math.min);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '혈당 부담 요약',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 15),
          _StatRow(
            icon: Icons.arrow_upward_rounded,
            color: AppColors.high,
            label: '최고 예상 상승폭',
            value: '+$high mg/dL',
          ),
          const Divider(height: 24),
          _StatRow(
            icon: Icons.arrow_downward_rounded,
            color: AppColors.blue,
            label: '최저 예상 상승폭',
            value: '+$low mg/dL',
          ),
          const Divider(height: 24),
          _StatRow(
            icon: Icons.restaurant_rounded,
            color: AppColors.medium,
            label: '분석한 식사',
            value: '${records.length}회',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
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
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .11),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _CoachingCard extends StatelessWidget {
  const _CoachingCard({required this.records});

  final List<MealRecord> records;

  @override
  Widget build(BuildContext context) {
    final highCount = records
        .where((record) => record.analysis.glucoseRisk.name == 'high')
        .length;
    final message = highCount >= 3
        ? '최근 혈당 부담이 높은 식사가 잦아요. 다음 식사에는 채소와 단백질을 먼저 먹고, 정제 탄수화물 양을 조금 줄여보세요.'
        : '최근 식사 흐름이 비교적 안정적이에요. 지금처럼 채소와 단백질을 챙기고 식후 10분 걷기를 이어가보세요.';
    return AppCard(
      color: AppColors.surfaceWarm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Icon(Icons.smart_toy_outlined, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 코칭 팁',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '모든 수치는 사진과 메뉴 정보를 바탕으로 한 AI 추정치입니다. 실제 혈당 측정 결과 및 의료진의 판단과 다를 수 있습니다.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
