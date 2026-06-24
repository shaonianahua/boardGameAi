import 'package:flutter/material.dart';

import '../../../../models/splendor_models.dart';
import '../widgets/splendor_info_card.dart';
import 'discard_tokens_panel.dart';

/// 当前合法行动面板。
///
/// 负责展示当前行动状态，并在需要时承载 pendingAction 的首个处理入口。
class LegalActionsPanel extends StatelessWidget {
  /// 构造合法行动面板。
  const LegalActionsPanel({
    required this.legalActions,
    required this.currentPlayer,
    required this.isSubmitting,
    required this.isActingAutoPlayer,
    required this.isLoading,
    required this.onSubmit,
    super.key,
  });

  /// 后端返回的合法行动响应。
  final SplendorLegalActionsResponse? legalActions;

  /// 当前行动玩家状态，用于展示 pendingAction 所需的玩家资源。
  final SplendorPlayerState currentPlayer;

  /// 行动是否正在提交。
  final bool isSubmitting;

  /// 当前是否正在等待本地 Bot 或 AI 玩家自动行动。
  final bool isActingAutoPlayer;

  /// 合法行动是否加载中。
  final bool isLoading;

  /// 提交一条后端返回的合法行动。
  final ValueChanged<SplendorLegalAction> onSubmit;

  @override
  Widget build(BuildContext context) {
    return SplendorInfoCard(title: '当前行动', child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    if (isActingAutoPlayer) {
      return Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${currentPlayer.name} 正在自动行动。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    if (isLoading) {
      return const LinearProgressIndicator();
    }

    final legalActions = this.legalActions;
    if (legalActions == null) {
      return Text('正在等待合法行动数据。', style: Theme.of(context).textTheme.bodySmall);
    }

    final pendingAction = legalActions.pendingAction;
    if (pendingAction != null) {
      if (pendingAction.type == SplendorActionType.discardTokens) {
        return DiscardTokensPanel(
          pendingAction: pendingAction,
          playerTokens: currentPlayer.tokens,
          actions: legalActions.actions,
          isSubmitting: isSubmitting,
          onSubmit: onSubmit,
        );
      }

      return Text(
        '当前有待处理行动：${pendingAction.type.value}',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      );
    }

    final takeTokenCount = legalActions.actions
        .where((item) => item.action.type == SplendorActionType.takeTokens)
        .length;

    return Text(
      takeTokenCount > 0
          ? '可在公共宝石区点击宝石拿取。'
          : legalActions.disabledReasons.isEmpty
          ? '当前没有可显示的行动。'
          : legalActions.disabledReasons.join('\n'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: legalActions.disabledReasons.isEmpty
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.66)
            : Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
