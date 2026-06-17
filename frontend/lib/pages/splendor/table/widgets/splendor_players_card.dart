import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import 'splendor_info_card.dart';
import 'splendor_player_summary_card.dart';

/// 玩家列表摘要卡。
class SplendorPlayersCard extends StatelessWidget {
  /// 构造玩家列表摘要卡。
  const SplendorPlayersCard({
    required this.players,
    required this.currentPlayerIndex,
    required this.cardsById,
    super.key,
  });

  /// 对局中的玩家状态。
  final List<SplendorPlayerState> players;

  /// 当前行动玩家下标。
  final int currentPlayerIndex;

  /// 发展卡 catalog 索引，用于玩家摘要展示已购卡牌资产。
  final Map<String, SplendorCard> cardsById;

  @override
  Widget build(BuildContext context) {
    return SplendorInfoCard(
      title: '玩家',
      child: Column(
        children: List<Widget>.generate(players.length, (index) {
          final player = players[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == players.length - 1 ? 0 : 10.h,
            ),
            child: SplendorPlayerSummaryCard(
              player: player,
              isCurrent: index == currentPlayerIndex,
              cardsById: cardsById,
            ),
          );
        }),
      ),
    );
  }
}
