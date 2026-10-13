import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/ai_api_service.dart';
import '../services/meal_history_store.dart';
import '../widgets/app_colors.dart';
import 'food_identification_screen.dart';
import 'result_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({
    super.key,
    this.imageBytes,
    this.imageSourceLabel,
    this.confirmedFoodName,
    this.calibrationProfileId,
  });

  final Uint8List? imageBytes;
  final String? imageSourceLabel;
  final String? confirmedFoodName;
  final String? calibrationProfileId;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  final List<Timer> _timers = [];
  int _completedSteps = 0;
  AiApiException? _error;

  bool get _isIdentifying => widget.confirmedFoodName == null;

  @override
  void initState() {
    super.initState();
    _scheduleProgress();
    if (_isIdentifying) {
      _moveToFoodIdentification();
    } else {
      _moveToResult();
    }
  }

  void _scheduleProgress() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers
      ..clear()
      ..add(Timer(const Duration(milliseconds: 450), () => _setProgress(1)))
      ..add(Timer(const Duration(milliseconds: 1050), () => _setProgress(2)));
  }

  void _setProgress(int value) {
    if (mounted) setState(() => _completedSteps = value);
  }

  Future<void> _moveToFoodIdentification() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      final identification = await AiApiService.instance.identifyFoodCandidates(
        widget.imageBytes,
      );
      if (!mounted) return;
      setState(() => _completedSteps = 3);
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FoodIdentificationScreen(
            imageBytes: widget.imageBytes,
            imageSourceLabel: widget.imageSourceLabel,
            candidates: identification.candidates,
            profiles: identification.profiles,
            suggestedProfileId: identification.suggestedProfileId,
          ),
        ),
      );
    } on AiApiException catch (error) {
      _showError(error);
    } on Object catch (error) {
      _showError(AiApiException(AiApiErrorType.backend, detail: '$error'));
    }
  }

  Future<void> _moveToResult() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      final analysis = await AiApiService.instance.analyzeMeal(
        foodName: widget.confirmedFoodName ?? '',
        imageBytes: widget.imageBytes,
        calibrationProfileId: widget.calibrationProfileId,
      );
      final record = await MealHistoryStore.instance.addAnalysis(
        analysis,
        previewImageBytes: widget.imageBytes,
      );
      if (!mounted) return;
      setState(() => _completedSteps = 3);
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            analysis: record.analysis,
            imageBytes: widget.imageBytes,
            imageSourceLabel: widget.imageSourceLabel,
          ),
        ),
      );
    } on AiApiException catch (error) {
      _showError(error);
    } on Object catch (error) {
      _showError(AiApiException(AiApiErrorType.backend, detail: '$error'));
    }
  }

  void _showError(AiApiException error) {
    if (!mounted) return;
    for (final timer in _timers) {
      timer.cancel();
    }
    setState(() => _error = error);
  }

  void _retry() {
    setState(() {
      _error = null;
      _completedSteps = 0;
    });
    _scheduleProgress();
    if (_isIdentifying) {
      unawaited(_moveToFoodIdentification());
    } else {
      unawaited(_moveToResult());
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111819),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.imageBytes != null)
            Image.memory(widget.imageBytes!, fit: BoxFit.cover)
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF334B45), Color(0xFF0D1314)],
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x85000000),
                  Color(0x25000000),
                  Color(0xA8000000),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.mint,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 25, 24, 31),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_error != null)
                        _AnalysisError(
                          error: _error!,
                          onRetry: _retry,
                          onBack: () => Navigator.pop(context),
                        )
                      else ...[
                        Text(
                          _isIdentifying
                              ? 'AI가 음식을 찾고 있어요'
                              : 'AI가 영양 정보를 분석 중이에요',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _isIdentifying
                              ? '사진 속 메뉴 후보를 정리하고 있습니다.'
                              : '${widget.confirmedFoodName ?? '선택한 음식'}의 식사 부담 가이드를 만들고 있습니다.',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _AnalysisStep(
                          index: 1,
                          completedSteps: _completedSteps,
                          label: '음식 영역 인식',
                          detail: '접시와 주요 재료 확인',
                        ),
                        const SizedBox(height: 12),
                        _AnalysisStep(
                          index: 2,
                          completedSteps: _completedSteps,
                          label: _isIdentifying ? '메뉴 후보 검색' : '영양 성분 추정',
                          detail: _isIdentifying
                              ? '가능한 음식명 비교'
                              : '탄수화물·단백질·지방 분석',
                        ),
                        const SizedBox(height: 12),
                        _AnalysisStep(
                          index: 3,
                          completedSteps: _completedSteps,
                          label: _isIdentifying ? '확인 화면 준비' : '식사 부담 가이드 생성',
                          detail: _isIdentifying
                              ? '정확한 메뉴 확인 필요'
                              : '음식 양·영양 정보와 코칭 생성',
                        ),
                      ],
                    ],
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

class _AnalysisError extends StatelessWidget {
  const _AnalysisError({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final AiApiException error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.high, size: 34),
        const SizedBox(height: 12),
        Text(
          error.title,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          error.displayMessage,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 시도'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onBack, child: const Text('돌아가기')),
          ],
        ),
      ],
    );
  }
}

class _AnalysisStep extends StatelessWidget {
  const _AnalysisStep({
    required this.index,
    required this.completedSteps,
    required this.label,
    required this.detail,
  });

  final int index;
  final int completedSteps;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final completed = completedSteps >= index;
    final active = completedSteps + 1 == index;
    return Row(
      children: [
        Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: completed ? AppColors.lowSoft : AppColors.background,
            shape: BoxShape.circle,
          ),
          child: completed
              ? const Icon(Icons.check_rounded, color: AppColors.low, size: 17)
              : active
              ? const Padding(
                  padding: EdgeInsets.all(6),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          detail,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
