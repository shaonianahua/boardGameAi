import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';

/// AI 策略建议底部面板。
///
/// 面板负责展示上一条结构化建议，并提供手动请求入口；不在这里执行推荐行动。
class SplendorAiAdvicePanel extends StatelessWidget {
  /// 构造 AI 建议面板。
  const SplendorAiAdvicePanel({
    required this.advice,
    required this.streamLines,
    required this.isLoading,
    required this.onRequestAdvice,
    required this.onClose,
    this.scrollController,
    super.key,
  });

  /// 最近一次 AI 建议接口返回的数据；为空时展示等待请求的空状态。
  final SplendorAiAdviceResponse? advice;

  /// AI 建议流式接口逐段返回的展示文本。
  final List<String> streamLines;

  /// 当前是否正在请求 AI 建议，用于禁用按钮和展示加载状态。
  final bool isLoading;

  /// 点击面板内建议按钮时触发，由 controller 负责实际接口调用。
  final VoidCallback onRequestAdvice;

  /// bottom sheet 关闭回调。
  final VoidCallback onClose;

  /// 外部滚动控制器，方便在可拖拽底部面板中复用。
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentAdvice = advice;
    final selectedAction = currentAdvice?.selectedAction;

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
            if (currentAdvice != null) ...[
              _ConfidenceBadge(confidence: currentAdvice.decision.confidence),
              SizedBox(width: 4.w),
            ],
            IconButton(
              tooltip: '关闭',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        _RequestAdviceButton(
          hasAdvice: currentAdvice != null,
          isLoading: isLoading,
          onPressed: onRequestAdvice,
        ),
        SizedBox(height: 10.h),
        if (streamLines.isNotEmpty) ...[
          _StreamAdviceSection(
            lines: streamLines,
            isLoading: isLoading,
            isCompacted: !isLoading && currentAdvice != null,
          ),
          SizedBox(height: 10.h),
        ],
        if (currentAdvice == null)
          _EmptyAdviceState(isLoading: isLoading)
        else ...[
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
                  currentAdvice.decision.summary,
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
            items: currentAdvice.decision.reasoning,
            emptyText: '暂无推荐理由。',
          ),
          _AdviceSection(
            title: '备选行动',
            icon: Icons.alt_route_rounded,
            items: currentAdvice.decision.alternatives,
            emptyText: '暂无备选行动。',
          ),
          _AdviceSection(
            title: '对手威胁',
            icon: Icons.visibility_rounded,
            items: currentAdvice.decision.threats,
            emptyText: '暂无明显威胁。',
          ),
          _AdviceSection(
            title: '风险提示',
            icon: Icons.warning_amber_rounded,
            items: currentAdvice.decision.risks,
            emptyText: '暂无风险提示。',
          ),
        ],
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

/// AI 建议流式输出区域，模拟主流 AI 产品的逐段分析反馈。
class _StreamAdviceSection extends StatelessWidget {
  const _StreamAdviceSection({
    required this.lines,
    required this.isLoading,
    required this.isCompacted,
  });

  final List<String> lines;
  final bool isLoading;
  final bool isCompacted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayLines = isCompacted && lines.length > 3
        ? lines.sublist(lines.length - 3)
        : lines;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 17.w, color: colorScheme.tertiary),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  isLoading ? '实时分析中' : (isCompacted ? '分析摘要' : '实时分析'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (isCompacted && lines.length > displayLines.length)
                Text(
                  '已省略 ${lines.length - displayLines.length} 条',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (isLoading)
                SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          ...displayLines.map(
            (line) => Padding(
              padding: EdgeInsets.only(bottom: 5.h),
              child: Text(
                line,
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

/// 面板内的 AI 建议请求按钮。
class _RequestAdviceButton extends StatelessWidget {
  const _RequestAdviceButton({
    required this.hasAdvice,
    required this.isLoading,
    required this.onPressed,
  });

  final bool hasAdvice;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(isLoading ? '正在生成建议' : (hasAdvice ? '重新获取建议' : '获取 AI 建议')),
      ),
    );
  }
}

/// 尚未请求 AI 建议时展示的空状态。
class _EmptyAdviceState extends StatelessWidget {
  const _EmptyAdviceState({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            isLoading ? Icons.hourglass_top_rounded : Icons.tips_and_updates,
            color: colorScheme.primary,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              isLoading ? '正在分析当前局面...' : '还没有生成建议，点击上方按钮开始分析当前局面。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
