import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import 'splendor_info_card.dart';
import 'splendor_noble_tile.dart';

/// 贵族展示卡，把状态中的贵族 ID 映射成 catalog 中的需求和分数。
class SplendorNobleCard extends StatelessWidget {
  /// 构造贵族展示卡。
  const SplendorNobleCard({
    required this.nobles,
    required this.noblesById,
    required this.isLoadingCatalog,
    super.key,
  });

  /// 场上贵族 ID 列表。
  final List<String> nobles;

  /// 贵族索引。
  final Map<String, SplendorNoble> noblesById;

  /// catalog 是否正在加载。
  final bool isLoadingCatalog;

  @override
  Widget build(BuildContext context) {
    return SplendorInfoCard(
      title: '贵族',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoadingCatalog) const _CatalogLoadingText(),
          if (isLoadingCatalog) SizedBox(height: 12.h),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = nobles.length >= 3 ? 3 : 2;
              final tileWidth =
                  (constraints.maxWidth - (columnCount - 1) * 6.w) /
                  columnCount;
              return Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                children: nobles.map((id) {
                  return SizedBox(
                    width: tileWidth,
                    child: SplendorNobleTile(
                      noble: noblesById[id],
                      fallbackId: id,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CatalogLoadingText extends StatelessWidget {
  const _CatalogLoadingText();

  @override
  Widget build(BuildContext context) {
    return Text(
      '正在读取卡牌数据...',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}
