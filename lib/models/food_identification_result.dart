class CalibrationProfileSummary {
  const CalibrationProfileSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.sampleCount,
  });

  final String id;
  final String name;
  final String description;
  final int sampleCount;

  factory CalibrationProfileSummary.fromJson(Map<String, dynamic> json) {
    return CalibrationProfileSummary(
      id: (json['id'] as String? ?? '').trim(),
      name: _safePublicText(json['name'] as String?),
      description: _safePublicText(json['description'] as String?),
      sampleCount: _intFromJson(json['sampleCount']),
    );
  }
}

class FoodIdentificationResult {
  const FoodIdentificationResult({
    this.candidates = const [],
    this.profiles = const [],
    this.suggestedProfileId,
  });

  final List<String> candidates;
  final List<CalibrationProfileSummary> profiles;
  final String? suggestedProfileId;

  CalibrationProfileSummary? get suggestedProfile {
    final suggestedId = suggestedProfileId;
    if (suggestedId == null) return null;
    for (final profile in profiles) {
      if (profile.id == suggestedId) return profile;
    }
    return null;
  }
}

int _intFromJson(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _safePublicText(String? value) {
  final text = value?.trim() ?? '';
  if (_containsUnsafeMedicalCopy(text)) return '';
  return text;
}

bool _containsUnsafeMedicalCopy(String value) {
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
