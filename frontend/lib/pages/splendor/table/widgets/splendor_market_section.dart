import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import 'splendor_development_card_tile.dart';

/// 单个等级的市场卡牌区域。
class SplendorMarketSection extends StatelessWidget {
  /// 构造单个等级的市场卡牌区域。
  const SplendorMarketSection({
    required this.title,
    required this.cardIds,
    required this.cardsById,
    required this.onCardSelected,
    super.key,
  });

  /// 等级标题。
  final String title;

  /// 该等级当前市场卡牌 ID。
  final List<String> cardIds;

  /// 发展卡索引。
  final Map<String, SplendorCard> cardsById;

  /// 用户点选一张可展示的发展卡后的回调。
  final ValueChanged<SplendorCard> onCardSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
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
}
