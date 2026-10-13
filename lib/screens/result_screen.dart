import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/meal_analysis.dart';
import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';
import 'photo_input_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.analysis,
    this.imageBytes,
    this.imageSourceLabel,
    this.showActionButtons = true,
  });

  final MealAnalysis analysis;
  final Uint8List? imageBytes;
  final String? imageSourceLabel;
  final bool showActionButtons;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('분석 결과'),
            Text(
              'LOW42 식사 부담 가이드',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '안내',
            onPressed: () => _showInfo(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _MealImage(imageBytes: imageBytes),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        analysis.foodName,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        analysis.portionDescription,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                RiskPill(level: analysis.mealBurdenLevel),
              ],
            ),
            if (analysis.ingredients.isNotEmpty) ...[
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: analysis.ingredients
                    .take(5)
                    .map((item) => _IngredientChip(label: item.name))
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),
            _PredictionCard(analysis: analysis),
            if (analysis.calibration?.applied == true) ...[
              const SizedBox(height: 14),
              _CalibrationCard(calibration: analysis.calibration!),
            ] else if (analysis.calibration?.note.isNotEmpty == true) ...[
              const SizedBox(height: 14),
              _CalibrationWarningCard(calibration: analysis.calibration!),
            ],
            const SizedBox(height: 14),
            _NutritionCard(analysis: analysis),
            const SizedBox(height: 14),
            _CoachingCard(analysis: analysis),
            const SizedBox(height: 14),
            const _MedicalNotice(),
            if (showActionButtons) ...[
              const SizedBox(height: 20),
              GradientButton(
                label: '기록 저장 완료',
                icon: Icons.check_circle_rounded,
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const PhotoInputScreen()),
                ),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text(
                  '다른 식사 분석',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '식사 부담 가이드 안내',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 10),
            Text(
              '사진 속 음식과 메뉴명, 숟가락·젓가락·접시의 상대적 크기를 참고해 분량과 영양 정보를 추정합니다. 식기 실제 크기, 촬영 각도, 조리법에 따라 결과는 달라질 수 있습니다.',
              style: TextStyle(
                color: AppColors.muted,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealImage extends StatelessWidget {
  const _MealImage({this.imageBytes});

  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 1.6,
        child: imageBytes != null
            ? Image.memory(imageBytes!, fit: BoxFit.cover)
            : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE5F8F1), Color(0xFFEAF8F9)],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_rounded,
                      color: AppColors.primary.withValues(alpha: .13),
                      size: 125,
                    ),
                    const Icon(
                      Icons.ramen_dining_rounded,
                      color: AppColors.primaryDark,
                      size: 48,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.analysis});

  final MealAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '식사 부담 가이드',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                analysis.mealBurdenLevel.label,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 36,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              RiskPill(level: analysis.mealBurdenLevel),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '분량·영양 구성 참고 점수 ${analysis.mealBurdenScore}/100 · ${analysis.portionDescription}',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          _RiskGauge(score: analysis.mealBurdenScore),
          const SizedBox(height: 13),
          Text(
            analysis.mealBurdenDescription,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard({required this.calibration});

  final MealCalibration calibration;

  @override
  Widget build(BuildContext context) {
    final ruleName = calibration.ruleName.isEmpty
        ? '등록된 보정 규칙'
        : calibration.ruleName;

    return AppCard(
      color: AppColors.lowSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: AppColors.primaryDark,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '제품·메뉴 데이터 반영',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '가이드 보정',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ruleName,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'AI 기본 ${_guideLabelFromScore(calibration.rawMealBurdenScore)}  →  '
              '제품 반영 ${_guideLabelFromScore(calibration.adjustedMealBurdenScore)}',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (calibration.sampleCount > 0) ...[
            const SizedBox(height: 9),
            Text(
              '등록 제품 정보 ${calibration.sampleCount}건을 참고했습니다.',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (calibration.note.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              calibration.note,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalibrationWarningCard extends StatelessWidget {
  const _CalibrationWarningCard({required this.calibration});

  final MealCalibration calibration;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFFFF4E5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFC06B00)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '선택한 보정이 적용되지 않았어요',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  calibration.note,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.45,
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

class _RiskGauge extends StatelessWidget {
  const _RiskGauge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final normalized = score.clamp(0, 100) / 100;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final markerX = (constraints.maxWidth - 12) * normalized;
            return SizedBox(
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 9,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF59D6D1),
                            Color(0xFF7BD66E),
                            Color(0xFFFFC45B),
                            Color(0xFFEF666B),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: markerX,
                    top: 3,
                    child: Container(
                      width: 12,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.ink, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x26132239), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '낮음',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '보통',
              style: TextStyle(
                color: AppColors.medium,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '높음',
              style: TextStyle(
                color: AppColors.high,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.analysis});

  final MealAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '추정 영양 정보',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                analysis.portionDescription,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _NutritionRow(
            label: '칼로리',
            value: '${analysis.calories} kcal',
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFFF9F43),
          ),
          const Divider(height: 22),
          _NutritionRow(
            label: '탄수화물',
            value: '${analysis.carbs} g',
            icon: Icons.grain_rounded,
            color: AppColors.medium,
          ),
          const Divider(height: 22),
          _NutritionRow(
            label: '단백질',
            value: '${analysis.protein} g',
            icon: Icons.fitness_center_rounded,
            color: AppColors.blue,
          ),
          const Divider(height: 22),
          _NutritionRow(
            label: '지방',
            value: '${analysis.fat} g',
            icon: Icons.opacity_rounded,
            color: AppColors.primary,
          ),
          const Divider(height: 22),
          _NutritionRow(
            label: '당류',
            value: '${analysis.sugar} g',
            icon: Icons.cookie_outlined,
            color: AppColors.high,
          ),
        ],
      ),
    );
  }
}

class _NutritionRow extends StatelessWidget {
  const _NutritionRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
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
  const _CoachingCard({required this.analysis});

  final MealAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final tip = switch (analysis.mealBurdenLevel) {
      MealBurdenLevel.low => '좋은 선택이에요. 지금의 식사 구성을 유지하고 천천히 먹어보세요.',
      MealBurdenLevel.medium =>
        '채소와 단백질을 먼저 먹고 탄수화물은 뒤에 먹으면 부담을 낮추는 데 도움이 됩니다.',
      MealBurdenLevel.high => '양을 조금 줄이고 식후 10~15분 가볍게 걸어 식사 부담을 낮춰보세요.',
    };
    return AppCard(
      color: AppColors.surfaceWarm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 23,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '일반 식사 팁',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tip,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12,
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

class _MedicalNotice extends StatelessWidget {
  const _MedicalNotice();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '이 결과는 사진 기반 식사 부담 가이드이며 실제 혈당 측정값이 아닙니다. 의료 진단·투약 판단에 사용하지 마세요.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _guideLabelFromScore(int score) {
  if (score >= 70) return '높음';
  if (score >= 40) return '보통';
  return '낮음';
}
