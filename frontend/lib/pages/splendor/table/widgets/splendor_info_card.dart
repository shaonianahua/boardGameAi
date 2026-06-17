import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 璀璨宝石桌面页内部通用信息卡。
///
/// 用于桌面页多个状态区保持一致的标题、间距和卡片样式。
class SplendorInfoCard extends StatelessWidget {
  /// 构造桌面信息卡。
  const SplendorInfoCard({required this.title, required this.child, super.key});

  /// 卡片标题。
  final String title;

  /// 卡片主体内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(10.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8.h),
            child,
          ],
        ),
      ),
    );
  }
}
