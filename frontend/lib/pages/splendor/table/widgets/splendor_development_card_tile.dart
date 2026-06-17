import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';
import 'splendor_cost_wrap.dart';

/// 发展卡简化卡面，展示等级、分数、奖励颜色和购买费用。
class SplendorDevelopmentCardTile extends StatelessWidget {
  /// 构造发展卡展示卡。
  const SplendorDevelopmentCardTile({
    required this.card,
    required this.fallbackId,
    super.key,
  });

  /// catalog 中对应的发展卡。
  final SplendorCard? card;

  /// catalog 缺失时回退显示的 ID。
  final String fallbackId;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    final colorScheme = Theme.of(context).colorScheme;

    if (card == null) {
      return SplendorMissingCatalogTile(label: fallbackId);
    }

    final bonusColor = gemColor(card.bonusColor);
    final bonusTextColor = readableTextColor(bonusColor);

    return SizedBox(
      height: 112.h,
      child: Container(
        decoration: BoxDecoration(
          color: bonusColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: bonusColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      levelLabel(card.level),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: bonusTextColor,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${card.prestige}',
                    style: TextStyle(
                      color: bonusTextColor,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(6.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gemName(card.bonusColor),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.62),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    SplendorCostWrap(gems: card.cost),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
