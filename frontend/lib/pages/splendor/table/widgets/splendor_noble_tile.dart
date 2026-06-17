import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';
import 'splendor_cost_wrap.dart';

/// 贵族简化卡面，展示分数和到访所需永久宝石。
class SplendorNobleTile extends StatelessWidget {
  /// 构造贵族展示卡。
  const SplendorNobleTile({
    required this.noble,
    required this.fallbackId,
    super.key,
  });

  /// catalog 中对应的贵族。
  final SplendorNoble? noble;

  /// catalog 缺失时回退显示的 ID。
  final String fallbackId;

  @override
  Widget build(BuildContext context) {
    final noble = this.noble;
    final colorScheme = Theme.of(context).colorScheme;

    if (noble == null) {
      return SplendorMissingCatalogTile(label: fallbackId);
    }

    return Container(
      constraints: BoxConstraints(minHeight: 82.h),
      padding: EdgeInsets.all(7.w),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '贵族',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${noble.prestige}分',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            '需求',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 5.h),
          SplendorCostWrap(gems: noble.requirement),
        ],
      ),
    );
  }
}
