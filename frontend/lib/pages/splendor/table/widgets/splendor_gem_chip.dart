import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 宝石数量标签。
class SplendorGemChip extends StatelessWidget {
  /// 构造宝石数量标签。
  const SplendorGemChip({
    required this.label,
    required this.count,
    required this.color,
    super.key,
  });

  /// 显示文字。
  final String label;

  /// 数量。
  final int count;

  /// 背景色。
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isLight = color.computeLuminance() > 0.72;

    return Semantics(
      label: '$label宝石$count个',
      child: Container(
        width: 42.w,
        height: 42.w,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: isLight ? Colors.black87 : Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
