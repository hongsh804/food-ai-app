enum GlucoseRisk {
  low('낮음'),
  medium('보통'),
  high('높음');

  const GlucoseRisk(this.label);

  final String label;

  static GlucoseRisk fromName(String name) {
    return GlucoseRisk.values.firstWhere(
      (risk) => risk.name == name,
      orElse: () => GlucoseRisk.medium,
    );
  }
}

class IngredientEstimate {
  const IngredientEstimate({
    required this.name,
    required this.amount,
    this.note = '',
  });

  final String name;
  final String amount;
  final String note;

  factory IngredientEstimate.fromJson(Map<String, dynamic> json) {
    return IngredientEstimate(
      name: json['name'] as String? ?? '알 수 없는 재료',
      amount: json['amount'] as String? ?? '양 추정 어려움',
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'amount': amount, 'note': note};
  }
}

class MealCalibration {
  const MealCalibration({
    required this.applied,
    required this.ruleId,
    required this.ruleName,
    required this.matchType,
    required this.mode,
    required this.rawEstimatedGlucoseRise,
    required this.adjustedEstimatedGlucoseRise,
    required this.sampleCount,
    required this.note,
  });

  final bool applied;
  final String ruleId;
  final String ruleName;
  final String matchType;
  final String mode;
  final int rawEstimatedGlucoseRise;
  final int adjustedEstimatedGlucoseRise;
  final int sampleCount;
  final String note;

  factory MealCalibration.fromJson(Map<String, dynamic> json) {
    final rawRise = _intFromJson(json['rawEstimatedGlucoseRise']);
    return MealCalibration(
      applied: json['applied'] == true,
      ruleId: (json['ruleId'] as String? ?? '').trim(),
      ruleName: (json['ruleName'] as String? ?? '').trim(),
      matchType: (json['matchType'] as String? ?? '').trim(),
      mode: (json['mode'] as String? ?? '').trim(),
      rawEstimatedGlucoseRise: rawRise,
      adjustedEstimatedGlucoseRise: _intFromJson(
        json['adjustedEstimatedGlucoseRise'],
        fallback: rawRise,
      ),
      sampleCount: _intFromJson(json['sampleCount']),
      note: (json['note'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'applied': applied,
      'ruleId': ruleId,
      'ruleName': ruleName,
      'matchType': matchType,
      'mode': mode,
      'rawEstimatedGlucoseRise': rawEstimatedGlucoseRise,
      'adjustedEstimatedGlucoseRise': adjustedEstimatedGlucoseRise,
      'sampleCount': sampleCount,
      'note': note,
    };
  }

  static int _intFromJson(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class MealAnalysis {
  const MealAnalysis({
    required this.foodName,
    required this.dateLabel,
    required this.glucoseSpikeScore,
    required this.estimatedGlucoseRise,
    required this.estimatedPeakMinutes,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.sugar,
    required this.glucoseRisk,
    required this.glucoseDescription,
    this.portionDescription = '1인분 기준 추정',
    this.ingredients = const [],
    this.calibration,
  });

  final String foodName;
  final String dateLabel;
  final int glucoseSpikeScore;
  final int estimatedGlucoseRise;
  final int estimatedPeakMinutes;
  final int calories;
  final int carbs;
  final int protein;
  final int fat;
  final int sugar;
  final GlucoseRisk glucoseRisk;
  final String glucoseDescription;
  final String portionDescription;
  final List<IngredientEstimate> ingredients;
  final MealCalibration? calibration;

  factory MealAnalysis.fromJson(Map<String, dynamic> json) {
    final glucoseRisk = GlucoseRisk.fromName(
      json['glucoseRisk'] as String? ?? GlucoseRisk.medium.name,
    );

    return MealAnalysis(
      foodName: json['foodName'] as String? ?? '알 수 없는 음식',
      dateLabel: json['dateLabel'] as String? ?? '',
      glucoseSpikeScore: _intFromJson(
        json['glucoseSpikeScore'],
        _defaultSpikeScore(glucoseRisk),
      ),
      estimatedGlucoseRise: _intFromJson(
        json['estimatedGlucoseRise'],
        _defaultRise(glucoseRisk),
      ),
      estimatedPeakMinutes: _intFromJson(
        json['estimatedPeakMinutes'],
        _defaultPeak(glucoseRisk),
      ),
      calories: _intFromJson(json['calories'], 620),
      carbs: _intFromJson(json['carbs'], 72),
      protein: _intFromJson(json['protein'], 26),
      fat: _intFromJson(json['fat'], 20),
      sugar: _intFromJson(json['sugar'], 12),
      glucoseRisk: glucoseRisk,
      glucoseDescription:
          json['glucoseDescription'] as String? ??
          '사진과 메뉴명을 바탕으로 한 AI 추정값입니다. 실제 조리법과 섭취량에 따라 식후 혈당 상승폭은 달라질 수 있습니다.',
      portionDescription: json['portionDescription'] as String? ?? '1인분 기준 추정',
      ingredients: _ingredientsFromJson(json['ingredients']),
      calibration: _calibrationFromJson(json['calibration']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foodName': foodName,
      'dateLabel': dateLabel,
      'glucoseSpikeScore': glucoseSpikeScore,
      'estimatedGlucoseRise': estimatedGlucoseRise,
      'estimatedPeakMinutes': estimatedPeakMinutes,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'sugar': sugar,
      'glucoseRisk': glucoseRisk.name,
      'glucoseDescription': glucoseDescription,
      'portionDescription': portionDescription,
      'ingredients': [
        for (final ingredient in ingredients) ingredient.toJson(),
      ],
      if (calibration != null) 'calibration': calibration!.toJson(),
    };
  }

  MealAnalysis copyWith({
    String? foodName,
    String? dateLabel,
    int? glucoseSpikeScore,
    int? estimatedGlucoseRise,
    int? estimatedPeakMinutes,
    int? calories,
    int? carbs,
    int? protein,
    int? fat,
    int? sugar,
    GlucoseRisk? glucoseRisk,
    String? glucoseDescription,
    String? portionDescription,
    List<IngredientEstimate>? ingredients,
    MealCalibration? calibration,
  }) {
    return MealAnalysis(
      foodName: foodName ?? this.foodName,
      dateLabel: dateLabel ?? this.dateLabel,
      glucoseSpikeScore: glucoseSpikeScore ?? this.glucoseSpikeScore,
      estimatedGlucoseRise: estimatedGlucoseRise ?? this.estimatedGlucoseRise,
      estimatedPeakMinutes: estimatedPeakMinutes ?? this.estimatedPeakMinutes,
      calories: calories ?? this.calories,
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      sugar: sugar ?? this.sugar,
      glucoseRisk: glucoseRisk ?? this.glucoseRisk,
      glucoseDescription: glucoseDescription ?? this.glucoseDescription,
      portionDescription: portionDescription ?? this.portionDescription,
      ingredients: ingredients ?? this.ingredients,
      calibration: calibration ?? this.calibration,
    );
  }

  static const MealAnalysis demoResult = MealAnalysis(
    foodName: '돈코츠 라멘',
    dateLabel: '오늘 점심',
    glucoseSpikeScore: 88,
    estimatedGlucoseRise: 55,
    estimatedPeakMinutes: 75,
    calories: 780,
    carbs: 82,
    protein: 30,
    fat: 34,
    sugar: 6,
    glucoseRisk: GlucoseRisk.high,
    glucoseDescription:
        '면의 정제 탄수화물 비중이 높아 식후 혈당 상승폭이 크게 추정됩니다. 차슈나 계란, 숙주를 먼저 먹고 면 양을 줄이면 상승 부담을 낮추는 데 도움이 됩니다.',
    portionDescription: '라멘 1그릇 기준 추정',
    ingredients: [
      IngredientEstimate(name: '라멘 면', amount: '약 180g', note: '혈당 상승의 주 요인'),
      IngredientEstimate(name: '차슈', amount: '2~3장', note: '단백질/지방'),
      IngredientEstimate(name: '삶은 계란', amount: '1/2~1개', note: '단백질'),
      IngredientEstimate(name: '숙주/파', amount: '약간', note: '채소류'),
    ],
  );

  static const List<MealAnalysis> sampleHistory = [
    MealAnalysis(
      foodName: '현미 닭가슴살 샐러드',
      dateLabel: '오늘 아침',
      glucoseSpikeScore: 28,
      estimatedGlucoseRise: 18,
      estimatedPeakMinutes: 90,
      calories: 430,
      carbs: 38,
      protein: 36,
      fat: 14,
      sugar: 7,
      glucoseRisk: GlucoseRisk.low,
      glucoseDescription: '식이섬유와 단백질 비중이 좋아 혈당 반응이 비교적 완만할 것으로 예상됩니다.',
      portionDescription: '샐러드 1접시 기준 추정',
      ingredients: [
        IngredientEstimate(name: '닭가슴살', amount: '약 100g'),
        IngredientEstimate(name: '현미', amount: '약 1/2공기'),
        IngredientEstimate(name: '채소', amount: '한 줌 이상'),
      ],
    ),
    demoResult,
    MealAnalysis(
      foodName: '딸기 생크림 케이크',
      dateLabel: '어제 오후',
      glucoseSpikeScore: 92,
      estimatedGlucoseRise: 62,
      estimatedPeakMinutes: 45,
      calories: 560,
      carbs: 68,
      protein: 8,
      fat: 28,
      sugar: 46,
      glucoseRisk: GlucoseRisk.high,
      glucoseDescription:
          '당류 비중이 높아 혈당이 빠르게 오를 가능성이 큽니다. 양을 줄이거나 식후 산책을 추천합니다.',
      portionDescription: '케이크 1조각 기준 추정',
      ingredients: [
        IngredientEstimate(name: '케이크 시트', amount: '1조각'),
        IngredientEstimate(name: '생크림', amount: '많음'),
        IngredientEstimate(name: '딸기/시럽', amount: '일부'),
      ],
    ),
    MealAnalysis(
      foodName: '연어 아보카도 포케',
      dateLabel: '어제 점심',
      glucoseSpikeScore: 61,
      estimatedGlucoseRise: 34,
      estimatedPeakMinutes: 70,
      calories: 610,
      carbs: 58,
      protein: 34,
      fat: 25,
      sugar: 9,
      glucoseRisk: GlucoseRisk.medium,
      glucoseDescription: '탄수화물은 중간 정도이며 지방과 단백질이 있어 식후 혈당 상승폭은 중간 정도로 예상됩니다.',
      portionDescription: '포케 1그릇 기준 추정',
      ingredients: [
        IngredientEstimate(name: '연어', amount: '약 80~100g'),
        IngredientEstimate(name: '밥/곡물', amount: '약 1/2~2/3공기'),
        IngredientEstimate(name: '아보카도', amount: '약 1/4~1/2개'),
        IngredientEstimate(name: '채소', amount: '한 줌'),
      ],
    ),
  ];

  static MealAnalysis fromConfirmedFoodName(String foodName) {
    final trimmedFoodName = foodName.trim().isEmpty
        ? '알 수 없는 음식'
        : foodName.trim();
    final lowerFoodName = trimmedFoodName.toLowerCase();

    if (trimmedFoodName.contains('라멘') ||
        trimmedFoodName.contains('라면') ||
        lowerFoodName.contains('ramen')) {
      return demoResult.copyWith(
        foodName: trimmedFoodName,
        dateLabel: '오늘 식사',
        glucoseDescription:
            '면류는 정제 탄수화물 비중이 높아 식후 혈당 상승폭이 크게 추정됩니다. 차슈, 계란, 채소를 먼저 먹고 면 양을 조절하면 부담을 낮추는 데 도움이 됩니다.',
      );
    }

    if (trimmedFoodName.contains('샐러드') || lowerFoodName.contains('salad')) {
      return const MealAnalysis(
        foodName: '샐러드',
        dateLabel: '오늘 식사',
        glucoseSpikeScore: 28,
        estimatedGlucoseRise: 18,
        estimatedPeakMinutes: 90,
        calories: 430,
        carbs: 32,
        protein: 30,
        fat: 19,
        sugar: 8,
        glucoseRisk: GlucoseRisk.low,
        glucoseDescription:
            '채소와 단백질 비중이 높아 식후 혈당 상승폭은 작게 추정됩니다. 단, 드레싱이나 곁들인 빵이 많으면 상승폭이 커질 수 있습니다.',
        portionDescription: '샐러드 1접시 기준 추정',
        ingredients: [
          IngredientEstimate(name: '채소', amount: '한 줌 이상'),
          IngredientEstimate(name: '단백질 재료', amount: '약 80~120g'),
          IngredientEstimate(name: '드레싱', amount: '1~2큰술'),
        ],
      ).copyWith(foodName: trimmedFoodName);
    }

    if (trimmedFoodName.contains('떡볶이') ||
        trimmedFoodName.contains('케이크') ||
        trimmedFoodName.contains('김밥') ||
        trimmedFoodName.contains('카레') ||
        trimmedFoodName.contains('파스타')) {
      return MealAnalysis(
        foodName: trimmedFoodName,
        dateLabel: '오늘 식사',
        glucoseSpikeScore: 86,
        estimatedGlucoseRise: 54,
        estimatedPeakMinutes: 60,
        calories: 760,
        carbs: 104,
        protein: 22,
        fat: 24,
        sugar: 18,
        glucoseRisk: GlucoseRisk.high,
        glucoseDescription:
            '$trimmedFoodName은 탄수화물 또는 당류 비중이 높을 가능성이 있어 식후 혈당 상승폭이 크게 추정됩니다. 양 조절과 식후 가벼운 걷기를 권장합니다.',
        portionDescription: '사진 또는 메뉴명 기준 1인분 추정',
        ingredients: [
          IngredientEstimate(name: '주 탄수화물', amount: '1인분'),
          IngredientEstimate(name: '소스/양념', amount: '보통~많음'),
          IngredientEstimate(name: '단백질/채소', amount: '일부'),
        ],
      );
    }

    return MealAnalysis(
      foodName: trimmedFoodName,
      dateLabel: '오늘 식사',
      glucoseSpikeScore: 62,
      estimatedGlucoseRise: 34,
      estimatedPeakMinutes: 70,
      calories: 620,
      carbs: 72,
      protein: 26,
      fat: 20,
      sugar: 12,
      glucoseRisk: GlucoseRisk.medium,
      glucoseDescription:
          '$trimmedFoodName은 사진과 메뉴명을 바탕으로 식후 혈당 상승폭이 중간 정도로 추정됩니다. 실제 조리법, 양, 소스에 따라 결과는 달라질 수 있습니다.',
      portionDescription: '사진 또는 메뉴명 기준 1인분 추정',
      ingredients: const [
        IngredientEstimate(name: '주재료', amount: '1인분'),
        IngredientEstimate(name: '탄수화물/소스', amount: '양 추정 필요'),
      ],
    );
  }

  static int _defaultSpikeScore(GlucoseRisk risk) {
    switch (risk) {
      case GlucoseRisk.low:
        return 30;
      case GlucoseRisk.medium:
        return 62;
      case GlucoseRisk.high:
        return 88;
    }
  }

  static int _defaultRise(GlucoseRisk risk) {
    switch (risk) {
      case GlucoseRisk.low:
        return 18;
      case GlucoseRisk.medium:
        return 34;
      case GlucoseRisk.high:
        return 55;
    }
  }

  static int _defaultPeak(GlucoseRisk risk) {
    switch (risk) {
      case GlucoseRisk.low:
        return 90;
      case GlucoseRisk.medium:
        return 70;
      case GlucoseRisk.high:
        return 60;
    }
  }

  static int _intFromJson(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static List<IngredientEstimate> _ingredientsFromJson(Object? value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map(
          (item) =>
              IngredientEstimate.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((ingredient) => ingredient.name.trim().isNotEmpty)
        .toList();
  }

  static MealCalibration? _calibrationFromJson(Object? value) {
    if (value is! Map) return null;
    return MealCalibration.fromJson(Map<String, dynamic>.from(value));
  }
}
