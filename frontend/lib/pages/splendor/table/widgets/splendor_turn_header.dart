import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 当前回合摘要卡。
class SplendorTurnHeader extends StatelessWidget {
  /// 构造当前回合摘要。
  const SplendorTurnHeader({
    required this.turnIndex,
    required this.currentPlayerName,
    required this.status,
    super.key,
  });

  /// 当前回合序号，从 0 开始。
  final int turnIndex;

  /// 当前行动玩家名称。
  final String currentPlayerName;

  /// 当前对局状态。
  final String status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '第 ${turnIndex + 1} 回合',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '当前玩家：$currentPlayerName',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6.h),
            Text(
              '状态：$status',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
