import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import 'splendor_info_card.dart';
import 'splendor_market_section.dart';

/// 市场卡牌展示卡，把状态中的卡牌 ID 映射成 catalog 中的真实卡牌内容。
class SplendorMarketCard extends StatelessWidget {
  /// 构造市场卡牌展示卡。
  const SplendorMarketCard({
    required this.markets,
    required this.cardsById,
    required this.isLoadingCatalog,
    required this.onCardSelected,
    super.key,
  });

  /// 当前市场卡牌区域。
  final SplendorCardArea markets;

  /// 发展卡索引。
  final Map<String, SplendorCard> cardsById;

  /// catalog 是否正在加载。
  final bool isLoadingCatalog;

  /// 用户点选一张市场发展卡后的回调，页面层负责决定买入或预留。
  final ValueChanged<SplendorCard> onCardSelected;

  @override
  Widget build(BuildContext context) {
    return SplendorInfoCard(
      title: '市场卡牌',
      child: Column(
        children: [
          if (isLoadingCatalog) const _CatalogLoadingText(),
          if (isLoadingCatalog) SizedBox(height: 12.h),
          SplendorMarketSection(
            title: '三级',
            cardIds: markets.level3,
            cardsById: cardsById,
            onCardSelected: onCardSelected,
          ),
          SizedBox(height: 14.h),
          SplendorMarketSection(
            title: '二级',
            cardIds: markets.level2,
            cardsById: cardsById,
            onCardSelected: onCardSelected,
          ),
          SizedBox(height: 14.h),
          SplendorMarketSection(
            title: '一级',
            cardIds: markets.level1,
            cardsById: cardsById,
            onCardSelected: onCardSelected,
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
