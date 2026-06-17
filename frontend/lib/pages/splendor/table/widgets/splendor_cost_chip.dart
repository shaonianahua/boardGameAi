import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../splendor_card_style_helpers.dart';

/// 单个颜色费用标签。
class SplendorCostChip extends StatelessWidget {
  /// 构造单色费用标签。
  const SplendorCostChip({
    required this.colorKey,
    required this.count,
    super.key,
  });

  /// 宝石颜色 key。
  final String colorKey;

  /// 该颜色对应数量。
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = gemColor(colorKey);
    final textColor = readableTextColor(color);

    return Container(
      constraints: BoxConstraints(minWidth: 20.w),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
