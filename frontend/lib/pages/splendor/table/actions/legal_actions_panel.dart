import 'package:flutter/material.dart';

import '../../../../models/splendor_models.dart';
import '../widgets/splendor_info_card.dart';

/// 当前合法行动面板。
///
/// 负责展示当前行动状态；具体拿宝石操作在公共宝石池中完成。
class LegalActionsPanel extends StatelessWidget {
  /// 构造合法行动面板。
  const LegalActionsPanel({
    required this.legalActions,
    required this.isLoading,
    super.key,
  });

  /// 后端返回的合法行动响应。
  final SplendorLegalActionsResponse? legalActions;

  /// 合法行动是否加载中。
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SplendorInfoCard(title: '当前行动', child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const LinearProgressIndicator();
    }

    final legalActions = this.legalActions;
    if (legalActions == null) {
      return Text('正在等待合法行动数据。', style: Theme.of(context).textTheme.bodySmall);
    }

    if (legalActions.pendingAction != null) {
      return Text(
        '当前有待处理行动：${legalActions.pendingAction!.type.value}',
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
