import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';
import 'splendor_development_card_tile.dart';
import 'splendor_gem_chip.dart';

/// 玩家资产详情面板。
///
/// 用于当前玩家直接展示，也用于点击其他玩家后弹窗查看公开信息。
class SplendorPlayerAssetsPanel extends StatelessWidget {
  /// 构造玩家资产详情面板。
  const SplendorPlayerAssetsPanel({
    required this.player,
    required this.cardsById,
    this.showTokens = false,
    this.showReservedCards = false,
    this.onReservedCardSelected,
    super.key,
  });

  /// 要展示的玩家状态。
  final SplendorPlayerState player;

  /// 发展卡 catalog 索引，用于把已购和预留卡 ID 映射成卡牌信息。
  final Map<String, SplendorCard> cardsById;

  /// 是否展示玩家当前手里的 token。
  final bool showTokens;

  /// 是否展示玩家预留卡详情。
  final bool showReservedCards;

  /// 点击预留卡时触发；为空时预留卡只展示不可交互卡面。
  final ValueChanged<SplendorCard>? onReservedCardSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '卡牌资产',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${player.score} 分',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        _BonusSummary(player: player),
        SizedBox(height: 8.h),
        _PurchasedCardSummary(
          cardIds: player.purchasedCards,
          cardsById: cardsById,
        ),
        if (showReservedCards) ...[
          SizedBox(height: 12.h),
          _ReservedCardsSection(
            cardIds: player.reservedCards,
            cardsById: cardsById,
            onCardSelected: onReservedCardSelected,
          ),
        ],
        if (showTokens) ...[
          SizedBox(height: 12.h),
          _TokenSection(tokens: player.tokens),
        ],
      ],
    );
  }
}

/// 玩家已购发展卡提供的永久宝石汇总。
class _BonusSummary extends StatelessWidget {
  const _BonusSummary({required this.player});

  final SplendorPlayerState player;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: [
        _BonusChip(colorKey: 'white', count: player.bonuses.white),
        _BonusChip(colorKey: 'blue', count: player.bonuses.blue),
        _BonusChip(colorKey: 'green', count: player.bonuses.green),
        _BonusChip(colorKey: 'red', count: player.bonuses.red),
        _BonusChip(colorKey: 'black', count: player.bonuses.black),
      ],
    );
  }
}

/// 单个永久宝石数量标签。
class _BonusChip extends StatelessWidget {
  const _BonusChip({required this.colorKey, required this.count});

  final String colorKey;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = gemColor(colorKey);
    final textColor = readableTextColor(color);

    return Container(
      constraints: BoxConstraints(minWidth: 44.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.14)),
      ),
      child: Text(
        '${gemShortName(colorKey)} $count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 12.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 已购分数卡列表。
///
/// 永久宝石数量已在上方五色汇总展示，这里只补充哪些已购卡提供分数。
class _PurchasedCardSummary extends StatelessWidget {
  const _PurchasedCardSummary({required this.cardIds, required this.cardsById});

  final List<String> cardIds;
  final Map<String, SplendorCard> cardsById;

  @override
  Widget build(BuildContext context) {
    final scoreCards = cardIds
        .where((cardId) {
          final card = cardsById[cardId];
          return card == null || card.prestige > 0;
        })
        .toList(growable: false);

    if (scoreCards.isEmpty) {
      return _EmptyText(text: '暂无分数卡');
    }

    return Wrap(
      spacing: 5.w,
      runSpacing: 5.h,
      children: scoreCards.map((cardId) {
        return _ScoreCardChip(card: cardsById[cardId], fallbackId: cardId);
      }).toList(),
    );
  }
}

/// 已购分数卡小标签，不重复展示卡牌颜色。
class _ScoreCardChip extends StatelessWidget {
  const _ScoreCardChip({required this.card, required this.fallbackId});

  final SplendorCard? card;
  final String fallbackId;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    if (card == null) {
      return _FallbackCardChip(label: fallbackId);
    }

    return Container(
      width: 46.w,
      height: 32.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        '${card.prestige}分',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// catalog 缺失时的已购卡兜底标签。
class _FallbackCardChip extends StatelessWidget {
  const _FallbackCardChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46.w,
      height: 32.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// 预留卡详情区域，用完整发展卡卡面展示方便识别购买费用。
class _ReservedCardsSection extends StatelessWidget {
  const _ReservedCardsSection({
    required this.cardIds,
    required this.cardsById,
    required this.onCardSelected,
  });

  final List<String> cardIds;
  final Map<String, SplendorCard> cardsById;
  final ValueChanged<SplendorCard>? onCardSelected;

  @override
  Widget build(BuildContext context) {
    return _SectionBlock(
      title: '预留卡牌',
      child: cardIds.isEmpty
          ? const _EmptyText(text: '暂无预留卡牌')
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6.w,
                mainAxisSpacing: 6.h,
                mainAxisExtent: 128.h,
              ),
              itemCount: cardIds.length,
              itemBuilder: (context, index) {
                final cardId = cardIds[index];
                final card = cardsById[cardId];
                return SplendorDevelopmentCardTile(
                  card: card,
                  fallbackId: cardId,
                  onTap: card == null || onCardSelected == null
                      ? null
                      : () => onCardSelected!(card),
                );
              },
            ),
    );
  }
}

/// 当前手里 token 展示区域。
class _TokenSection extends StatelessWidget {
  const _TokenSection({required this.tokens});

  final SplendorTokenSet tokens;

  @override
  Widget build(BuildContext context) {
    return _SectionBlock(
      title: '手里宝石',
      child: Wrap(
        spacing: 6.w,
        runSpacing: 6.h,
        children: [
          SplendorGemChip(label: '白', count: tokens.white, color: Colors.white),
          SplendorGemChip(label: '蓝', count: tokens.blue, color: Colors.blue),
          SplendorGemChip(label: '绿', count: tokens.green, color: Colors.green),
          SplendorGemChip(label: '红', count: tokens.red, color: Colors.red),
          SplendorGemChip(
            label: '黑',
            count: tokens.black,
            color: Colors.black87,
          ),
          SplendorGemChip(label: '金', count: tokens.gold, color: Colors.amber),
        ],
      ),
    );
  }
}

/// 资产详情内部小分区。
class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 6.h),
        child,
      ],
    );
  }
}

/// 空列表占位文案。
class _EmptyText extends StatelessWidget {
  const _EmptyText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
