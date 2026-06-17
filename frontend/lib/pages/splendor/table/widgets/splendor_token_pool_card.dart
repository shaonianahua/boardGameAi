import 'package:flutter/material.dart';

import '../../../../models/splendor_models.dart';
import '../actions/take_tokens_panel.dart';
import 'splendor_info_card.dart';

/// 公共 token 池展示卡。
class SplendorTokenPoolCard extends StatelessWidget {
  /// 构造公共 token 池卡片。
  const SplendorTokenPoolCard({
    required this.tokenPool,
    required this.legalActions,
    required this.isLoadingLegalActions,
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  /// 公共 token 状态。
  final SplendorTokenSet tokenPool;

  /// 当前合法行动，用于判断公共宝石池点击选择是否可提交。
  final SplendorLegalActionsResponse? legalActions;

  /// 合法行动是否加载中。
  final bool isLoadingLegalActions;

  /// 行动是否提交中。
  final bool isSubmitting;

  /// 提交一条拿宝石合法行动。
  final ValueChanged<SplendorLegalAction> onSubmit;

  @override
  Widget build(BuildContext context) {
    return SplendorInfoCard(
      title: '公共宝石',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoadingLegalActions)
            const LinearProgressIndicator()
          else
            TakeTokensPanel(
              actions: legalActions?.actions ?? const [],
              tokenPool: tokenPool,
              isSubmitting: isSubmitting,
              onSubmit: onSubmit,
            ),
        ],
      ),
    );
  }
}
