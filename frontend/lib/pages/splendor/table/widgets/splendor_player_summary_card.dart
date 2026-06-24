import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import 'splendor_gem_chip.dart';
import 'splendor_player_assets_panel.dart';

/// 玩家状态摘要卡。
class SplendorPlayerSummaryCard extends StatelessWidget {
  /// 构造玩家摘要卡。
  const SplendorPlayerSummaryCard({
    required this.player,
    required this.isCurrent,
    required this.cardsById,
    this.onReservedCardSelected,
    super.key,
  });

  /// 玩家状态。
  final SplendorPlayerState player;

  /// 是否是当前行动玩家。
  final bool isCurrent;

  /// 发展卡 catalog 索引，用于展示玩家已购卡牌提供的宝石和分数。
  final Map<String, SplendorCard> cardsById;

  /// 当前玩家点击预留卡时触发，用于购买预留卡；为空时预留卡只展示。
  final ValueChanged<SplendorCard>? onReservedCardSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isCurrent
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? colorScheme.primary.withValues(alpha: 0.32)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (player.type == SplendorPlayerType.bot) ...[
                      SizedBox(width: 6.w),
                      Icon(
                        _automaticPlayerIcon(player),
                        size: 15.w,
                        color: colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${player.score} 分',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              SplendorGemChip(
                label: '白',
                count: player.tokens.white,
                color: Colors.white,
              ),
              SplendorGemChip(
                label: '蓝',
                count: player.tokens.blue,
                color: Colors.blue,
              ),
              SplendorGemChip(
                label: '绿',
                count: player.tokens.green,
                color: Colors.green,
              ),
              SplendorGemChip(
                label: '红',
                count: player.tokens.red,
                color: Colors.red,
              ),
              SplendorGemChip(
                label: '黑',
                count: player.tokens.black,
                color: Colors.black87,
              ),
              SplendorGemChip(
                label: '金',
                count: player.tokens.gold,
                color: Colors.amber,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'token ${player.tokens.white + player.tokens.blue + player.tokens.green + player.tokens.red + player.tokens.black + player.tokens.gold} / bonus ${player.bonuses.white + player.bonuses.blue + player.bonuses.green + player.bonuses.red + player.bonuses.black} / 预留 ${player.reservedCards.length}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
          SizedBox(height: 10.h),
          SplendorPlayerAssetsPanel(
            player: player,
            cardsById: cardsById,
            showReservedCards: true,
            onReservedCardSelected: onReservedCardSelected,
          ),
        ],
      ),
    );
  }
}

/// 根据自动玩家类型返回玩家摘要卡中的身份图标。
IconData _automaticPlayerIcon(SplendorPlayerState player) {
  return SplendorBotLevel.fromJson(player.botLevel) == SplendorBotLevel.ai
      ? Icons.auto_awesome_rounded
      : Icons.smart_toy_rounded;
}
