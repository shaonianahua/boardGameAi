import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../models/splendor_models.dart';
import 'table/actions/legal_actions_panel.dart';
import 'table/splendor_catalog_lookup.dart';
import 'table/splendor_table_controller.dart';
import 'table/widgets/splendor_market_card.dart';
import 'table/widgets/splendor_noble_card.dart';
import 'table/widgets/splendor_player_summary_card.dart';
import 'table/widgets/splendor_token_pool_card.dart';

/// 璀璨宝石对局桌面页。
///
/// 页面只负责组装视觉结构和把交互交给控制器。
class SplendorTablePage extends StatefulWidget {
  /// 构造桌面页。
  const SplendorTablePage({super.key});

  @override
  State<SplendorTablePage> createState() => _SplendorTablePageState();
}

class _SplendorTablePageState extends State<SplendorTablePage> {
  late final SplendorTableController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(SplendorTableController());
    controller.initialize(
      Get.arguments is SplendorSessionResponse
          ? Get.arguments as SplendorSessionResponse
          : null,
    );
  }

  @override
  void dispose() {
    Get.delete<SplendorTableController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('璀璨宝石'),
        toolbarHeight: 44.h,
        actions: [
          Obx(
            () => IconButton(
              tooltip: '刷新对局',
              onPressed: controller.isRefreshing.value
                  ? null
                  : controller.refreshSession,
              icon: controller.isRefreshing.value
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          final response = controller.sessionResponse.value;
          final catalog = controller.catalog.value;
          final lookup = SplendorCatalogLookup(catalog);

          return response == null
              ? const _EmptySessionView()
              : ListView(
                  padding: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 14.h),
                  children: [
                    _OpponentStrip(
                      players: response.state.players,
                      currentPlayerIndex: response.state.currentPlayerIndex,
                    ),
                    SizedBox(height: 8.h),
                    SplendorMarketCard(
                      markets: response.state.markets,
                      cardsById: lookup.cardsById,
                      isLoadingCatalog: controller.isLoadingCatalog.value,
                    ),
                    SizedBox(height: 8.h),
                    SplendorTokenPoolCard(
                      tokenPool: response.state.tokenPool,
                      legalActions: controller.legalActions.value,
                      isLoadingLegalActions:
                          controller.isLoadingLegalActions.value,
                      isSubmitting: controller.isSubmittingAction.value,
                      onSubmit: controller.submitLegalAction,
                    ),
                    SizedBox(height: 8.h),
                    SplendorNobleCard(
                      nobles: response.state.nobles,
                      noblesById: lookup.noblesById,
                      isLoadingCatalog: controller.isLoadingCatalog.value,
                    ),
                    SizedBox(height: 10.h),
                    _TurnPrompt(
                      turnIndex: response.state.currentTurnIndex,
                      currentPlayerName: response
                          .state
                          .players[response.state.currentPlayerIndex]
                          .name,
                    ),
                    SizedBox(height: 8.h),
                    SplendorPlayerSummaryCard(
                      player: response
                          .state
                          .players[response.state.currentPlayerIndex],
                      isCurrent: true,
                    ),
                    SizedBox(height: 8.h),
                    LegalActionsPanel(
                      legalActions: controller.legalActions.value,
                      isLoading: controller.isLoadingLegalActions.value,
                    ),
                  ],
                );
        }),
      ),
    );
  }
}

/// 顶部对手摘要条。
class _OpponentStrip extends StatelessWidget {
  const _OpponentStrip({
    required this.players,
    required this.currentPlayerIndex,
  });

  final List<SplendorPlayerState> players;
  final int currentPlayerIndex;

  @override
  Widget build(BuildContext context) {
    final opponents = players
        .where((player) => player.seatIndex != currentPlayerIndex)
        .toList(growable: false);

    if (opponents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: opponents.map((player) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            child: _CompactOpponentCard(player: player),
          ),
        );
      }).toList(),
    );
  }
}

/// 顶部紧凑对手卡。
class _CompactOpponentCard extends StatelessWidget {
  const _CompactOpponentCard({required this.player});

  final SplendorPlayerState player;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${player.score}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'T${_tokenTotal(player.tokens)}/10  R${player.reservedCards.length}/3',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.66),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 当前回合提示。
class _TurnPrompt extends StatelessWidget {
  const _TurnPrompt({required this.turnIndex, required this.currentPlayerName});

  final int turnIndex;
  final String currentPlayerName;

  @override
  Widget build(BuildContext context) {
    return Text(
      '第 ${turnIndex + 1} 回合，$currentPlayerName 请选择一项行动',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );
  }
}

/// 没有路由参数时的空状态。
class _EmptySessionView extends StatelessWidget {
  const _EmptySessionView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          '没有找到当前对局，请返回首页重新创建。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

int _tokenTotal(SplendorTokenSet tokens) {
  return tokens.white +
      tokens.blue +
      tokens.green +
      tokens.red +
      tokens.black +
      tokens.gold;
}
