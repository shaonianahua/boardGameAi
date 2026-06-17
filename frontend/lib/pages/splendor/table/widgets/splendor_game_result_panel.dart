import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';

/// 终局状态和结果面板。
///
/// 展示最后一轮提示，以及对局结束后的胜者和分数排行。
class SplendorGameResultPanel extends StatelessWidget {
  /// 构造终局状态面板。
  const SplendorGameResultPanel({required this.state, super.key});

  /// 当前完整对局状态。
  final SplendorGameState state;

  @override
  Widget build(BuildContext context) {
    if (!state.finalRound.triggered &&
        state.status != SplendorSessionStatus.finished) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isFinished = state.status == SplendorSessionStatus.finished;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isFinished
            ? colorScheme.primary.withValues(alpha: 0.1)
            : colorScheme.secondary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFinished
              ? colorScheme.primary.withValues(alpha: 0.28)
              : colorScheme.secondary.withValues(alpha: 0.32),
        ),
      ),
      child: isFinished
          ? _FinishedResult(state: state)
          : _FinalRoundHint(state: state),
    );
  }
}

/// 最后一轮进行中的提示。
class _FinalRoundHint extends StatelessWidget {
  const _FinalRoundHint({required this.state});

  final SplendorGameState state;

  @override
  Widget build(BuildContext context) {
    final triggeredBy = _playerName(state.finalRound.triggeredByPlayerIndex);
    final roundEndPlayer = _playerName(state.finalRound.roundEndPlayerIndex);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.flag_outlined,
          color: Theme.of(context).colorScheme.secondary,
          size: 20.w,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最后一轮',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 3.h),
              Text(
                '$triggeredBy 已达到 15 分，$roundEndPlayer 行动结束后结算胜负。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _playerName(int? index) {
    if (index == null || index < 0 || index >= state.players.length) {
      return '当前玩家';
    }
    return state.players[index].name;
  }
}

/// 对局结束后的胜者和排行。
class _FinishedResult extends StatelessWidget {
  const _FinishedResult({required this.state});

  final SplendorGameState state;

  @override
  Widget build(BuildContext context) {
    final winner = _winner;
    final ranking = _ranking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 22.w,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                winner == null ? '对局结束' : '${winner.name} 获胜',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        ...ranking.map((player) => _RankingRow(player: player)),
      ],
    );
  }

  SplendorPlayerState? get _winner {
    final winnerIndex = state.winnerPlayerIndex;
    if (winnerIndex == null ||
        winnerIndex < 0 ||
        winnerIndex >= state.players.length) {
      return null;
    }
    return state.players[winnerIndex];
  }

  List<SplendorPlayerState> get _ranking {
    final players = [...state.players];
    players.sort((left, right) {
      if (right.score != left.score) {
        return right.score - left.score;
      }
      return left.purchasedCards.length - right.purchasedCards.length;
    });
    return players;
  }
}

/// 单个玩家最终排行行。
class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.player});

  final SplendorPlayerState player;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 5.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '${player.score}分 / ${player.purchasedCards.length}张卡',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
