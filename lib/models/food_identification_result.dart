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
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
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
