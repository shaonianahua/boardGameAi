import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../models/splendor_models.dart';

/// 返回非 0 宝石条目，供费用和贵族需求展示使用。
List<MapEntry<String, int>> nonZeroGemEntries(SplendorGemSet gems) {
  return [
    MapEntry('white', gems.white),
    MapEntry('blue', gems.blue),
    MapEntry('green', gems.green),
    MapEntry('red', gems.red),
    MapEntry('black', gems.black),
  ].where((entry) => entry.value > 0).toList(growable: false);
}

/// 后端等级数字转成 UI 展示文本。
String levelLabel(int level) {
  return switch (level) {
    1 => 'I',
    2 => 'II',
    3 => 'III',
    _ => '$level',
  };
}

/// 宝石颜色英文 key 转中文名。
String gemName(String colorKey) {
  return switch (colorKey) {
    'white' => '白',
    'blue' => '蓝',
    'green' => '绿',
    'red' => '红',
    'black' => '黑',
    'gold' => '金',
    _ => colorKey,
  };
}

/// 宝石颜色英文 key 转短中文名。
String gemShortName(String colorKey) => gemName(colorKey);

/// 宝石颜色英文 key 转 UI 颜色。
Color gemColor(String colorKey) {
  return switch (colorKey) {
    'white' => Colors.white,
    'blue' => Colors.blue,
    'green' => Colors.green,
    'red' => Colors.red,
    'black' => Colors.black87,
    'gold' => Colors.amber,
    _ => Colors.grey,
  };
}

/// 根据背景色亮度选择可读文字颜色。
Color readableTextColor(Color backgroundColor) {
  return backgroundColor.computeLuminance() > 0.72
      ? Colors.black87
      : Colors.white;
}

/// catalog 未加载到对应 ID 时的兜底展示。
class SplendorMissingCatalogTile extends StatelessWidget {
  /// 构造 catalog 缺失兜底卡。
  const SplendorMissingCatalogTile({required this.label, super.key});

  /// 兜底展示的 ID。
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(minHeight: 88.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
