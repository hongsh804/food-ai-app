import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/food_identification_result.dart';
import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';
import 'analyzing_screen.dart';

class FoodIdentificationScreen extends StatefulWidget {
  const FoodIdentificationScreen({
    super.key,
    this.imageBytes,
    this.imageSourceLabel,
    this.candidates = const [],
    this.profiles = const [],
    this.suggestedProfileId,
  });

  final Uint8List? imageBytes;
  final String? imageSourceLabel;
  final List<String> candidates;
  final List<CalibrationProfileSummary> profiles;
  final String? suggestedProfileId;

  @override
  State<FoodIdentificationScreen> createState() =>
      _FoodIdentificationScreenState();
}

class _FoodIdentificationScreenState extends State<FoodIdentificationScreen> {
  static const _hiddenLabels = {'음식명 직접 입력 필요', '사진 분석 실패', '알 수 없는 음식'};
  late final TextEditingController _controller;
  String? _selectedCandidate;
  String? _selectedProfileId;

  List<String> get _candidates => widget.candidates
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && !_hiddenLabels.contains(item))
      .take(5)
      .toList();

  @override
  void initState() {
    super.initState();
    _selectedCandidate = _candidates.isEmpty ? null : _candidates.first;
    _controller = TextEditingController(text: _selectedCandidate ?? '');
    _controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _select(String candidate) {
    setState(() {
      _selectedCandidate = candidate;
      _controller.text = candidate;
      _controller.selection = TextSelection.collapsed(offset: candidate.length);
    });
  }

  void _submit() {
    final foodName = _controller.text.trim();
    if (foodName.isEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AnalyzingScreen(
          imageBytes: widget.imageBytes,
          imageSourceLabel: widget.imageSourceLabel,
          confirmedFoodName: foodName,
          calibrationProfileId: _selectedProfileId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('음식 확인')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (widget.imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 1.55,
                  child: Image.memory(widget.imageBytes!, fit: BoxFit.cover),
                ),
              )
            else
              Container(
                height: 170,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.primary,
                  size: 52,
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              '사진 속 음식이 맞나요?',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              _candidates.isEmpty
                  ? 'AI가 메뉴를 확정하지 못했어요. 정확한 메뉴명을 직접 입력해주세요.'
                  : '가장 비슷한 메뉴를 선택하거나 직접 수정해주세요.',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_candidates.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  for (final candidate in _candidates)
                    ChoiceChip(
                      label: Text(candidate),
                      selected: _selectedCandidate == candidate,
                      selectedColor: AppColors.lowSoft,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: _selectedCandidate == candidate
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                      labelStyle: TextStyle(
                        color: _selectedCandidate == candidate
                            ? AppColors.primaryDark
                            : AppColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                      onSelected: (_) => _select(candidate),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 19),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onTap: () => setState(() => _selectedCandidate = null),
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: '정확한 메뉴명',
                hintText: '예: 현미 닭가슴살 샐러드',
                prefixIcon: Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '조리 방식 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '등록 제품을 선택할 때만 해당 혈당 보정값을 적용합니다. 등록 사진 일치는 자동으로 적용되지 않습니다.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _CalibrationProfileOption(
                    title: '일반 조리',
                    description: '등록된 제품 보정값을 적용하지 않습니다.',
                    selected: _selectedProfileId == null,
                    onTap: () => setState(() => _selectedProfileId = null),
                  ),
                  for (final profile in widget.profiles) ...[
                    const Divider(height: 1, indent: 52),
                    _CalibrationProfileOption(
                      title: profile.name,
                      description: profile.description.isEmpty
                          ? '등록된 제품·레시피 보정을 적용합니다.'
                          : profile.description,
                      sampleCount: profile.sampleCount,
                      suggested: profile.id == widget.suggestedProfileId,
                      selected: _selectedProfileId == profile.id,
                      onTap: () =>
                          setState(() => _selectedProfileId = profile.id),
                    ),
                  ],
                  if (widget.profiles.isEmpty) ...[
                    const Divider(height: 1, indent: 52),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 13, 16, 15),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.muted,
                            size: 18,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '현재 선택할 수 있는 등록 제품 프로필이 없습니다.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: '이 음식으로 분석하기',
              icon: Icons.auto_awesome_rounded,
              onPressed: _controller.text.trim().isEmpty ? null : _submit,
            ),
            const SizedBox(height: 16),
            const Text(
              '메뉴명이 정확할수록 영양 성분과 식후 혈당 부담 예측이 더 유용해집니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalibrationProfileOption extends StatelessWidget {
  const _CalibrationProfileOption({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.sampleCount = 0,
    this.suggested = false,
  });

  final String title;
  final String description;
  final int sampleCount;
  final bool suggested;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primaryDark : AppColors.muted,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: selected
                                ? AppColors.primaryDark
                                : AppColors.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (suggested) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lowSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '등록 사진 일치',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sampleCount > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '보정 표본 $sampleCount건',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
