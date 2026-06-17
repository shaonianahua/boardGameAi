import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';
import '../widgets/splendor_cost_wrap.dart';

/// 市场发展卡行动面板。
///
/// 根据后端返回的合法行动匹配当前卡牌可执行的购买或预留动作；前端不自行计算购买规则。
class CardActionsSheet extends StatefulWidget {
  /// 构造卡牌行动面板。
  const CardActionsSheet({
    required this.card,
    required this.actions,
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  /// 被用户点选的市场发展卡。
  final SplendorCard card;

  /// 当前玩家全部合法行动，用于筛选当前卡的买入和预留动作。
  final List<SplendorLegalAction> actions;

  /// 外部是否已有行动提交中。
  final bool isSubmitting;

  /// 提交匹配到的合法行动。
  final Future<void> Function(SplendorLegalAction action) onSubmit;

  /// 打开市场发展卡行动面板。
  static Future<void> show({
    required BuildContext context,
    required SplendorCard card,
    required List<SplendorLegalAction> actions,
    required bool isSubmitting,
    required Future<void> Function(SplendorLegalAction action) onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: 393.w),
      builder: (context) {
        return CardActionsSheet(
          card: card,
          actions: actions,
          isSubmitting: isSubmitting,
          onSubmit: onSubmit,
        );
      },
    );
  }

  @override
  State<CardActionsSheet> createState() => _CardActionsSheetState();
}

class _CardActionsSheetState extends State<CardActionsSheet> {
  bool _isSubmitting = false;

  SplendorLegalAction? get _buyAction {
    return _firstMatchingAction(SplendorActionType.buyCard);
  }

  SplendorLegalAction? get _reserveAction {
    return _firstMatchingAction(SplendorActionType.reserveCard);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final colorScheme = Theme.of(context).colorScheme;
    final bonusColor = gemColor(card.bonusColor);
    final bonusTextColor = readableTextColor(bonusColor);
    final disabled = widget.isSubmitting || _isSubmitting;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 18.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bonusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    gemName(card.bonusColor),
                    style: TextStyle(
                      color: bonusTextColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${levelLabel(card.level)} 级发展卡',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${card.prestige} 分，提供${gemName(card.bonusColor)}色永久宝石',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              '购买费用',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 6.h),
            SplendorCostWrap(gems: card.cost),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: disabled || _reserveAction == null
                        ? null
                        : () => _submit(_reserveAction!),
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(_reserveAction == null ? '不可预留' : '预留'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: disabled || _buyAction == null
                        ? null
                        : () => _submit(_buyAction!),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(_buyAction == null ? '不可购买' : '购买'),
                  ),
                ),
              ],
            ),
            if (_buyAction == null && _reserveAction == null) ...[
              SizedBox(height: 10.h),
              Text(
                '当前回合这张卡没有可提交的行动。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.58),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  SplendorLegalAction? _firstMatchingAction(SplendorActionType actionType) {
    for (final item in widget.actions) {
      final payload = item.action.payload;
      final isMatched =
          item.action.type == actionType &&
          payload['source'] == 'market' &&
          payload['cardId'] == widget.card.id;
      if (isMatched) {
        return item;
      }
    }
    return null;
  }

  Future<void> _submit(SplendorLegalAction action) async {
    setState(() {
      _isSubmitting = true;
    });
    await widget.onSubmit(action);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
