import 'package:flutter/material.dart';

import '../models/meal_analysis.dart';
import 'app_colors.dart';

class RiskBadge extends StatelessWidget {
  const RiskBadge({super.key, required this.level, this.compact = false});

  final MealBurdenLevel level;
  final bool compact;

  Color get _color {
    switch (level) {
      case MealBurdenLevel.low:
        return AppColors.low;
      case MealBurdenLevel.medium:
        return AppColors.medium;
      case MealBurdenLevel.high:
        return AppColors.high;
    }
  }

  Color get _backgroundColor {
    if (level == MealBurdenLevel.low) return AppColors.lowSoft;
    return _color.withValues(alpha: 0.12);
  }

  Color get _borderColor {
    if (level == MealBurdenLevel.low) return AppColors.lowBorder;
    return _color.withValues(alpha: 0.22);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 9,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.restaurant_rounded,
            size: compact ? 14 : 18,
            color: _color,
          ),
          const SizedBox(width: 6),
          Text(
            '식사 부담 ${level.label}',
            style: TextStyle(
              color: _color,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
