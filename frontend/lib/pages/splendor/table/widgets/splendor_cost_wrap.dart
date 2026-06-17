import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';
import 'splendor_cost_chip.dart';

/// 宝石费用或需求集合展示。
class SplendorCostWrap extends StatelessWidget {
  /// 构造宝石费用展示区域。
  const SplendorCostWrap({required this.gems, super.key});

  /// 费用或需求宝石集合。
  final SplendorGemSet gems;

  @override
  Widget build(BuildContext context) {
    final entries = nonZeroGemEntries(gems);

    if (entries.isEmpty) {
      return Text(
        '无',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    return Wrap(
      spacing: 3.w,
      runSpacing: 3.h,
      children: entries.map((entry) {
        return SplendorCostChip(colorKey: entry.key, count: entry.value);
      }).toList(),
    );
  }
}
