import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';

/// AI 策略建议底部面板。
///
/// 第一版展示后端返回的结构化建议，不在这里执行行动；后续流式内容可以继续复用这些区块。
class SplendorAiAdvicePanel extends StatelessWidget {
  /// 构造 AI 建议面板。
  const SplendorAiAdvicePanel({
    required this.advice,
    required this.onClose,
    this.scrollController,
    super.key,
  });

  /// AI 建议接口返回的数据。
  final SplendorAiAdviceResponse advice;

  /// bottom sheet 关闭回调。
  final VoidCallback onClose;

  /// 外部滚动控制器，方便在可拖拽底部面板中复用。
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedAction = advice.selectedAction;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 22.h),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'AI 建议',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            _ConfidenceBadge(confidence: advice.decision.confidence),
            SizedBox(width: 4.w),
            IconButton(
              tooltip: '关闭',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                advice.decision.summary,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.primary,
                ),
              ),
              if (selectedAction != null) ...[
                SizedBox(height: 8.h),
                Text(
                  _actionText(selectedAction.action),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 10.h),
        _AdviceSection(
          title: '推荐理由',
          icon: Icons.psychology_alt_rounded,
          items: advice.decision.reasoning,
          emptyText: '暂无推荐理由。',
        ),
        _AdviceSection(
          title: '备选行动',
          icon: Icons.alt_route_rounded,
          items: advice.decision.alternatives,
          emptyText: '暂无备选行动。',
        ),
        _AdviceSection(
          title: '对手威胁',
          icon: Icons.visibility_rounded,
          items: advice.decision.threats,
          emptyText: '暂无明显威胁。',
        ),
        _AdviceSection(
          title: '风险提示',
          icon: Icons.warning_amber_rounded,
          items: advice.decision.risks,
          emptyText: '暂无风险提示。',
        ),
      ],
    );
  }

  String _actionText(SplendorAction action) {
    final payload = action.payload;
    return switch (action.type) {
      SplendorActionType.takeTokens =>
        '推荐行动：拿取 ${_tokenText(payload['tokens'])}',
      SplendorActionType.reserveCard => _reserveText(payload),
      SplendorActionType.buyCard => '推荐行动：购买卡牌 ${payload['cardId'] ?? ''}',
      SplendorActionType.discardTokens =>
        '推荐行动：弃掉 ${_tokenText(payload['tokens'])}',
      SplendorActionType.chooseNoble => '推荐行动：选择贵族',
      SplendorActionType.nobleVisit => '推荐行动：获得贵族',
    };
  }

  String _reserveText(JsonMap payload) {
    if (payload['source'] == 'deck') {
      return '推荐行动：从 ${levelLabel(payload['level'] as int? ?? 0)} 级牌堆盲抽预留';
    }
    return '推荐行动：预留卡牌 ${payload['cardId'] ?? ''}';
  }

  String _tokenText(Object? value) {
    if (value is! JsonMap) {
      return '宝石';
    }

    final entries = <String>[];
    for (final colorKey in ['white', 'blue', 'green', 'red', 'black', 'gold']) {
      final count = value[colorKey];
      if (count is int && count > 0) {
        entries.add('${gemName(colorKey)}$count');
      }
    }
    return entries.isEmpty ? '无' : entries.join('、');
  }
}

/// 置信度标签，用颜色和百分比提示建议强弱。
class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = (confidence.clamp(0, 1) * 100).round();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$percent%',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.74),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 建议面板中的一个文字区块。
class _AdviceSection extends StatelessWidget {
  const _AdviceSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayItems = items.isEmpty ? [emptyText] : items;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17.w, color: colorScheme.primary),
              SizedBox(width: 6.w),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          ...displayItems.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.35,
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
