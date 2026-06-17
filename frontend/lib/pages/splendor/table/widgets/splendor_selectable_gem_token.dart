import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../splendor_card_style_helpers.dart';

/// 可点击或静态展示的圆形宝石 token。
///
/// 用于拿宝石、弃宝石等需要展示“当前数量 + 已选择数量”的局部交互。
class SplendorSelectableGemToken extends StatelessWidget {
  /// 构造宝石 token 圆点。
  const SplendorSelectableGemToken({
    required this.colorKey,
    required this.count,
    this.selectedCount = 0,
    this.enabled = true,
    this.canAdd = true,
    this.onTap,
    super.key,
  });

  /// 宝石颜色 key，例如 `white`、`blue`、`gold`。
  final String colorKey;

  /// 当前展示的宝石数量，公共池场景表示池中数量，玩家场景表示手中数量。
  final int count;

  /// 当前已被用户选择的数量。
  final int selectedCount;

  /// 是否允许交互。
  final bool enabled;

  /// 当前是否还能继续增加该颜色选择。
  final bool canAdd;

  /// 点击回调；为空时按静态 token 展示。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = gemColor(colorKey);
    final textColor = readableTextColor(color);
    final isInteractive = onTap != null;
    final isDimmed =
        isInteractive && (!enabled || (!canAdd && selectedCount == 0));

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isDimmed ? null : onTap,
      child: Opacity(
        opacity: isDimmed
            ? 0.38
            : isInteractive
            ? 1
            : 0.72,
        child: SizedBox(
          width: 50.w,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42.w,
                    height: 42.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedCount > 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black.withValues(alpha: 0.14),
                        width: selectedCount > 0 ? 3 : 1,
                      ),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (selectedCount > 0)
                    Positioned(
                      right: -2.w,
                      top: -4.h,
                      child: Container(
                        width: 20.w,
                        height: 20.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$selectedCount',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                gemShortName(colorKey),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
