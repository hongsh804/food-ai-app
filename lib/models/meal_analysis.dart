enum MealBurdenLevel {
  low('낮음'),
  medium('보통'),
  high('높음');

  const MealBurdenLevel(this.label);

  final String label;

  static MealBurdenLevel fromName(String name) {
    return MealBurdenLevel.values.firstWhere(
      (level) => level.name == name,
      orElse: () => MealBurdenLevel.medium,
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
      name: _safePublicText(json['name'] as String?, fallback: '알 수 없는 재료'),
      amount: _safePublicText(json['amount'] as String?, fallback: '양 추정 어려움'),
      note: _safeIngredientNote(json['note'] as String?),
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
    required this.rawMealBurdenScore,
    required this.adjustedMealBurdenScore,
    required this.sampleCount,
    required this.note,
  });

  final bool applied;
  final String ruleId;
  final String ruleName;
  final String matchType;
  final String mode;
  final int rawMealBurdenScore;
  final int adjustedMealBurdenScore;
  final int sampleCount;
  final String note;

  factory MealCalibration.fromJson(Map<String, dynamic> json) {
    final rawScore = _scoreFromJson(
      json['rawMealBurdenScore'],
      legacyRise: json['rawEstimatedGlucoseRise'],
    );
    return MealCalibration(
      applied: json['applied'] == true,
      ruleId: (json['ruleId'] as String? ?? '').trim(),
      ruleName: _safePublicText(
        json['ruleName'] as String?,
        fallback: appliedFallbackRuleName(json['applied']),
      ),
      matchType: (json['matchType'] as String? ?? '').trim(),
      mode: (json['mode'] as String? ?? '').trim(),
      rawMealBurdenScore: rawScore,
      adjustedMealBurdenScore: _scoreFromJson(
        json['adjustedMealBurdenScore'],
        legacyRise: json['adjustedEstimatedGlucoseRise'],
        fallback: rawScore,
      ),
      sampleCount: _intFromJson(json['sampleCount']),
      note: _safeCalibrationNote(json['note'] as String?),
    );
  }

  static String appliedFallbackRuleName(Object? applied) {
    return applied == true ? '등록 LOW42 제품' : '';
  }

  Map<String, dynamic> toJson() {
    return {
      'applied': applied,
      'ruleId': ruleId,
      'ruleName': ruleName,
      'matchType': matchType,
      'mode': mode,
      'rawMealBurdenScore': rawMealBurdenScore,
      'adjustedMealBurdenScore': adjustedMealBurdenScore,
      'sampleCount': sampleCount,
      'note': note,
    };
  }

  static int _scoreFromJson(
    Object? value, {
    Object? legacyRise,
    int fallback = 0,
  }) {
    final score = _nullableIntFromJson(value);
    if (score != null) return score.clamp(0, 100);
    final rise = _nullableIntFromJson(legacyRise);
    if (rise != null) return (rise * 1.6).round().clamp(0, 100);
    return fallback;
  }

  static int _intFromJson(Object? value, {int fallback = 0}) {
    return _nullableIntFromJson(value) ?? fallback;
  }

  static int? _nullableIntFromJson(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _safeCalibrationNote(String? value) {
    final note = value?.trim() ?? '';
    if (_containsMedicalPredictionCopy(note)) return '';
    return note;
  }
}

class MealAnalysis {
  const MealAnalysis({
    required this.foodName,
    required this.dateLabel,
    required this.mealBurdenScore,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.sugar,
    required this.mealBurdenLevel,
    required this.mealBurdenDescription,
    this.portionDescription = '1인분 기준 추정',
    this.ingredients = const [],
    this.calibration,
  });

  final String foodName;
  final String dateLabel;
  final int mealBurdenScore;
  final int calories;
  final int carbs;
  final int protein;
  final int fat;
  final int sugar;
  final MealBurdenLevel mealBurdenLevel;
  final String mealBurdenDescription;
  final String portionDescription;
  final List<IngredientEstimate> ingredients;
  final MealCalibration? calibration;

  factory MealAnalysis.fromJson(Map<String, dynamic> json) {
    final level = MealBurdenLevel.fromName(
      (json['mealBurdenLevel'] ?? json['glucoseRisk']) as String? ??
          MealBurdenLevel.medium.name,
    );
    final score = _intFromJson(
      json['mealBurdenScore'] ?? json['glucoseSpikeScore'],
      _defaultBurdenScore(level),
    ).clamp(0, 100);

    return MealAnalysis(
      foodName: _safePublicText(
        json['foodName'] as String?,
        fallback: '확인한 음식',
      ),
      dateLabel: json['dateLabel'] as String? ?? '',
      mealBurdenScore: score,
      calories: _intFromJson(json['calories'], 620),
      carbs: _intFromJson(json['carbs'], 72),
      protein: _intFromJson(json['protein'], 26),
      fat: _intFromJson(json['fat'], 20),
      sugar: _intFromJson(json['sugar'], 12),
      mealBurdenLevel: level,
      mealBurdenDescription: _guideDescription(
        (json['mealBurdenDescription'] ?? json['glucoseDescription'])
            as String?,
        level,
      ),
      portionDescription: _safePublicText(
        json['portionDescription'] as String?,
        fallback: '사진 기준 약 1인분 추정',
      ),
      ingredients: _ingredientsFromJson(json['ingredients']),
      calibration: _calibrationFromJson(json['calibration']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foodName': foodName,
      'dateLabel': dateLabel,
      'mealBurdenScore': mealBurdenScore,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
      'sugar': sugar,
      'mealBurdenLevel': mealBurdenLevel.name,
      'mealBurdenDescription': mealBurdenDescription,
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
    int? mealBurdenScore,
    int? calories,
    int? carbs,
    int? protein,
    int? fat,
    int? sugar,
    MealBurdenLevel? mealBurdenLevel,
    String? mealBurdenDescription,
    String? portionDescription,
    List<IngredientEstimate>? ingredients,
    MealCalibration? calibration,
  }) {
    return MealAnalysis(
      foodName: foodName ?? this.foodName,
      dateLabel: dateLabel ?? this.dateLabel,
      mealBurdenScore: mealBurdenScore ?? this.mealBurdenScore,
      calories: calories ?? this.calories,
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      sugar: sugar ?? this.sugar,
      mealBurdenLevel: mealBurdenLevel ?? this.mealBurdenLevel,
      mealBurdenDescription:
          mealBurdenDescription ?? this.mealBurdenDescription,
      portionDescription: portionDescription ?? this.portionDescription,
      ingredients: ingredients ?? this.ingredients,
      calibration: calibration ?? this.calibration,
    );
  }

  static const MealAnalysis demoResult = MealAnalysis(
    foodName: '돈코츠 라멘',
    dateLabel: '오늘 점심',
    mealBurdenScore: 88,
    calories: 780,
    carbs: 82,
    protein: 30,
    fat: 34,
    sugar: 6,
    mealBurdenLevel: MealBurdenLevel.high,
    mealBurdenDescription:
        '면의 정제 탄수화물 비중과 추정 분량이 커 식사 부담이 높게 분류됐습니다. 차슈나 계란, 숙주를 먼저 먹고 면 양을 조절해보세요.',
    portionDescription: '라멘 1그릇 기준 추정',
    ingredients: [
      IngredientEstimate(name: '라멘 면', amount: '약 180g', note: '식사 부담의 주 요인'),
      IngredientEstimate(name: '차슈', amount: '2~3장', note: '단백질/지방'),
      IngredientEstimate(name: '삶은 계란', amount: '1/2~1개', note: '단백질'),
      IngredientEstimate(name: '숙주/파', amount: '약간', note: '채소류'),
    ],
  );

  static const List<MealAnalysis> sampleHistory = [
    MealAnalysis(
      foodName: '현미 닭가슴살 샐러드',
      dateLabel: '오늘 아침',
      mealBurdenScore: 28,
      calories: 430,
      carbs: 38,
      protein: 36,
      fat: 14,
      sugar: 7,
      mealBurdenLevel: MealBurdenLevel.low,
      mealBurdenDescription: '식이섬유와 단백질 비중이 좋아 식사 부담이 낮게 분류됐습니다.',
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
      mealBurdenScore: 92,
      calories: 560,
      carbs: 68,
      protein: 8,
      fat: 28,
      sugar: 46,
      mealBurdenLevel: MealBurdenLevel.high,
      mealBurdenDescription:
          '당류 비중과 추정 분량이 커 식사 부담이 높게 분류됐습니다. 양을 줄이거나 식후 가볍게 걸어보세요.',
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
      mealBurdenScore: 61,
      calories: 610,
      carbs: 58,
      protein: 34,
      fat: 25,
      sugar: 9,
      mealBurdenLevel: MealBurdenLevel.medium,
      mealBurdenDescription: '탄수화물은 중간 정도이며 지방과 단백질이 있어 식사 부담이 보통으로 분류됐습니다.',
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
        mealBurdenDescription:
            '면류는 정제 탄수화물 비중과 추정 분량이 커 식사 부담이 높게 분류됐습니다. 차슈, 계란, 채소를 먼저 먹고 면 양을 조절해보세요.',
      );
    }

    if (trimmedFoodName.contains('샐러드') || lowerFoodName.contains('salad')) {
      return const MealAnalysis(
        foodName: '샐러드',
        dateLabel: '오늘 식사',
        mealBurdenScore: 28,
        calories: 430,
        carbs: 32,
        protein: 30,
        fat: 19,
        sugar: 8,
        mealBurdenLevel: MealBurdenLevel.low,
        mealBurdenDescription:
            '채소와 단백질 비중이 높아 식사 부담이 낮게 분류됐습니다. 단, 드레싱이나 곁들인 빵이 많으면 부담이 커질 수 있습니다.',
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
        mealBurdenScore: 86,
        calories: 760,
        carbs: 104,
        protein: 22,
        fat: 24,
        sugar: 18,
        mealBurdenLevel: MealBurdenLevel.high,
        mealBurdenDescription:
            '$trimmedFoodName은 탄수화물 또는 당류 비중과 추정 분량을 바탕으로 식사 부담이 높게 분류됐습니다. 양을 조절하고 식후 가볍게 걸어보세요.',
        portionDescription: '사진 또는 메뉴명 기준 1인분 추정',
        ingredients: const [
          IngredientEstimate(name: '주 탄수화물', amount: '1인분'),
          IngredientEstimate(name: '소스/양념', amount: '보통~많음'),
          IngredientEstimate(name: '단백질/채소', amount: '일부'),
        ],
      );
    }

    return MealAnalysis(
      foodName: trimmedFoodName,
      dateLabel: '오늘 식사',
      mealBurdenScore: 62,
      calories: 620,
      carbs: 72,
      protein: 26,
      fat: 20,
      sugar: 12,
      mealBurdenLevel: MealBurdenLevel.medium,
      mealBurdenDescription:
          '$trimmedFoodName은 사진과 메뉴명, 추정 분량을 바탕으로 식사 부담이 보통으로 분류됐습니다. 실제 조리법, 양, 소스에 따라 결과는 달라질 수 있습니다.',
      portionDescription: '사진 또는 메뉴명 기준 1인분 추정',
      ingredients: const [
        IngredientEstimate(name: '주재료', amount: '1인분'),
        IngredientEstimate(name: '탄수화물/소스', amount: '양 추정 필요'),
      ],
    );
  }

  static int _defaultBurdenScore(MealBurdenLevel level) {
    return switch (level) {
      MealBurdenLevel.low => 30,
      MealBurdenLevel.medium => 62,
      MealBurdenLevel.high => 88,
    };
  }

  static String _guideDescription(String? value, MealBurdenLevel level) {
    final description = value?.trim() ?? '';
    if (description.isNotEmpty &&
        !_containsMedicalPredictionCopy(description)) {
      return description;
    }

    return switch (level) {
      MealBurdenLevel.low => '사진 속 음식 구성과 추정 분량을 바탕으로 식사 부담이 낮게 분류됐습니다.',
      MealBurdenLevel.medium => '사진 속 음식 구성과 추정 분량을 바탕으로 식사 부담이 보통으로 분류됐습니다.',
      MealBurdenLevel.high =>
        '사진 속 음식 구성과 추정 분량을 바탕으로 식사 부담이 높게 분류됐습니다. 양을 조절해보세요.',
    };
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

bool _containsMedicalPredictionCopy(String value) {
  final lower = value.toLowerCase();
  const blockedTerms = <String>[
    'mg/dl',
    'mg / dl',
    '혈당',
    '당뇨',
    '스파이크',
    '피크',
    '실측',
    '측정',
    '예측',
    '진단',
    '치료',
    '투약',
    '인슐린',
    '질병 예방',
    '질병 개선',
    '질병 완화',
  ];
  return blockedTerms.any(lower.contains);
}

String _safePublicText(String? value, {required String fallback}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty || _containsMedicalPredictionCopy(text)) return fallback;
  return text;
}

String _safeIngredientNote(String? value) {
  final note = value?.trim() ?? '';
  if (_containsMedicalPredictionCopy(note)) return '식사 구성 참고';
  return note;
}
