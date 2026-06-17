import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import 'splendor_development_card_tile.dart';

/// 单个等级的市场卡牌区域。
class SplendorMarketSection extends StatelessWidget {
  /// 构造单个等级的市场卡牌区域。
  const SplendorMarketSection({
    required this.title,
    required this.level,
    required this.cardIds,
    required this.cardsById,
    required this.onCardSelected,
    required this.actions,
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  /// 等级标题。
  final String title;

  /// 发展卡等级，用于匹配牌堆盲抽预留行动。
  final int level;

  /// 该等级当前市场卡牌 ID。
  final List<String> cardIds;

  /// 发展卡索引。
  final Map<String, SplendorCard> cardsById;

  /// 用户点选一张可展示的发展卡后的回调。
  final ValueChanged<SplendorCard> onCardSelected;

  /// 当前玩家全部合法行动，用于匹配本等级牌堆盲抽预留。
  final List<SplendorLegalAction> actions;

  /// 是否正在提交行动。
  final bool isSubmitting;

  /// 提交匹配到的盲抽预留行动。
  final ValueChanged<SplendorLegalAction> onSubmit;

  @override
  Widget build(BuildContext context) {
    final reserveDeckAction = _reserveDeckAction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Tooltip(
              message: '从$title牌堆盲抽预留',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                constraints: BoxConstraints.tightFor(width: 34.w, height: 34.w),
                tooltip: '盲抽预留',
                onPressed: isSubmitting || reserveDeckAction == null
                    ? null
                    : () => onSubmit(reserveDeckAction),
                icon: const Icon(Icons.style_outlined),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 18.w) / 4;
            return Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: cardIds.map((id) {
                final card = cardsById[id];
                return SizedBox(
                  width: tileWidth,
                  child: SplendorDevelopmentCardTile(
                    card: card,
                    fallbackId: id,
                    onTap: card == null ? null : () => onCardSelected(card),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  SplendorLegalAction? get _reserveDeckAction {
    for (final item in actions) {
      final payload = item.action.payload;
      final isMatched =
          item.action.type == SplendorActionType.reserveCard &&
          payload['source'] == 'deck' &&
          payload['level'] == level;
      if (isMatched) {
        return item;
      }
    }
    return null;
  }
}
