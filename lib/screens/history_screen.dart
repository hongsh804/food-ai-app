import 'package:flutter/material.dart';

import '../models/meal_record.dart';
import '../services/meal_history_store.dart';
import '../widgets/app_colors.dart';
import '../widgets/app_ui.dart';
import 'result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: MealHistoryStore.instance,
        builder: (context, _) {
          final records = MealHistoryStore.instance.records;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              embedded ? 20 : 4,
              20,
              embedded ? 116 : 30,
            ),
            children: [
              if (embedded) ...[
                const Text(
                  '식사 기록',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '분석한 식사를 날짜별로 모아봤어요.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
              ],
              _HistoryOverview(records: records),
              const SizedBox(height: 22),
              if (records.isEmpty)
                const _EmptyHistory()
              else
                ..._buildGroupedRecords(context, records),
            ],
          );
        },
      ),
    );

    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('식사 기록')),
      body: content,
    );
  }

  List<Widget> _buildGroupedRecords(
    BuildContext context,
    List<MealRecord> records,
  ) {
    final groups = <String, List<MealRecord>>{};
    for (final record in records) {
      groups.putIfAbsent(record.dayKey, () => []).add(record);
    }
    final widgets = <Widget>[];
    for (final group in groups.values) {
      widgets
        ..add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              group.first.dayLabel,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        )
        ..addAll(
          group.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HistoryTile(
                record: record,
                onTap: () => _openResult(context, record),
                onDelete: () => _confirmDelete(context, record),
              ),
            ),
          ),
        )
        ..add(const SizedBox(height: 10));
    }
    return widgets;
  }

  void _openResult(BuildContext context, MealRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          analysis: record.analysis,
          imageBytes: record.previewImageBytes,
          imageSourceLabel: record.previewImageBytes == null
              ? null
              : '저장된 음식 사진',
          showActionButtons: false,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MealRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('${record.analysis.foodName} 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.high)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await MealHistoryStore.instance.deleteRecord(record.id);
    }
  }
}

class _HistoryOverview extends StatelessWidget {
  const _HistoryOverview({required this.records});

  final List<MealRecord> records;

  @override
  Widget build(BuildContext context) {
    final scores = records
        .take(7)
        .map((record) => record.analysis.mealBurdenScore)
        .toList();
    final average = scores.isEmpty
        ? 0
        : (scores.reduce((a, b) => a + b) / scores.length).round();
    final balanced = records
        .where((record) => record.analysis.mealBurdenLevel.name == 'low')
        .length;
    return AppCard(
      color: AppColors.surfaceWarm,
      child: Row(
        children: [
          Expanded(
            child: _OverviewValue(value: '${records.length}', label: '전체 기록'),
          ),
          Container(width: 1, height: 42, color: AppColors.border),
          Expanded(
            child: _OverviewValue(value: '$average', label: '평균 부담 점수'),
          ),
          Container(width: 1, height: 42, color: AppColors.border),
          Expanded(
            child: _OverviewValue(value: '$balanced', label: '낮은 부담'),
          ),
        ],
      ),
    );
  }
}

class _OverviewValue extends StatelessWidget {
  const _OverviewValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final MealRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 52,
              height: 52,
              child: record.previewImageBytes != null
                  ? Image.memory(record.previewImageBytes!, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surfaceWarm,
                      child: const Icon(
                        Icons.ramen_dining_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.analysis.foodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${record.timeLabel} · ${record.analysis.calories} kcal',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                record.analysis.mealBurdenLevel.label,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                '식사 부담',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
            onSelected: (_) => onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('기록 삭제')),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 42),
          SizedBox(height: 12),
          Text('아직 저장된 식사 기록이 없어요.'),
        ],
      ),
    );
  }
}
