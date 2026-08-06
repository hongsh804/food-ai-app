import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';
import 'analyzing_screen.dart';

class FoodIdentificationScreen extends StatefulWidget {
  const FoodIdentificationScreen({
    super.key,
    this.imageBytes,
    this.imageSourceLabel,
    this.candidates = const [],
  });

  final Uint8List? imageBytes;
  final String? imageSourceLabel;
  final List<String> candidates;

  @override
  State<FoodIdentificationScreen> createState() =>
      _FoodIdentificationScreenState();
}

class _FoodIdentificationScreenState extends State<FoodIdentificationScreen> {
  static const _hiddenLabels = {'음식명 직접 입력 필요', '사진 분석 실패', '알 수 없는 음식'};
  late final TextEditingController _controller;
  String? _selectedCandidate;

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
