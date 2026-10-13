import 'package:flutter/material.dart';

import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 62,
                  maxWidth: 560,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      const BrandMark(size: 118),
                      const SizedBox(height: 26),
                      const _BrandTitle(),
                      const SizedBox(height: 10),
                      const Text(
                        '사진 한 장으로 음식의 구성과 양을 살펴보고\n식사 부담 가이드를 확인해보세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 16,
                          height: 1.65,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const _FeatureRow(),
                      const Spacer(flex: 3),
                      GradientButton(
                        label: '시작하기',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: onStart,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AI 식사 부담 가이드는 일반 참고 정보이며\n의료 진단이나 실제 혈당 측정을 대신하지 않습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'LOW'),
              TextSpan(
                text: '42',
                style: TextStyle(color: AppColors.primary),
              ),
            ],
          ),
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 38,
            letterSpacing: -1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 3),
        Text(
          '로우포티투',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 11,
            letterSpacing: 5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _Feature(icon: Icons.camera_alt_rounded, text: '사진·양 분석'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _Feature(icon: Icons.restaurant_rounded, text: '식사 부담 가이드'),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _Feature(icon: Icons.insights_rounded, text: '식습관 기록'),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 22),
          const SizedBox(height: 7),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
