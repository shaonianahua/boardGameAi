import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../models/splendor_models.dart';
import 'table/actions/card_actions_sheet.dart';
import 'table/actions/legal_actions_panel.dart';
import 'table/controller/splendor_table_controller.dart';
import 'table/splendor_catalog_lookup.dart';
import 'table/widgets/splendor_market_card.dart';
import 'table/widgets/splendor_noble_card.dart';
import 'table/widgets/splendor_player_assets_panel.dart';
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
          final legalActions = controller.legalActions.value;
          final actingPlayerIndex =
              legalActions?.playerIndex ??
              response?.state.currentPlayerIndex ??
              0;

          return response == null
              ? const _EmptySessionView()
              : ListView(
                  padding: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 14.h),
                  children: [
                    _OpponentStrip(
                      players: response.state.players,
                      currentPlayerIndex: response.state.currentPlayerIndex,
                      cardsById: lookup.cardsById,
                    ),
                    SizedBox(height: 8.h),
                    SplendorMarketCard(
                      markets: response.state.markets,
                      cardsById: lookup.cardsById,
                      isLoadingCatalog: controller.isLoadingCatalog.value,
                      onCardSelected: _showCardActions,
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
                      currentPlayer: response
                          .state
                          .players[response.state.currentPlayerIndex],
                      pendingAction:
                          controller.legalActions.value?.pendingAction,
                    ),
                    SizedBox(height: 8.h),
                    SplendorPlayerSummaryCard(
                      player: response
                          .state
                          .players[response.state.currentPlayerIndex],
                      isCurrent: true,
                      cardsById: lookup.cardsById,
                    ),
                    SizedBox(height: 8.h),
                    LegalActionsPanel(
                      legalActions: legalActions,
                      currentPlayer: response.state.players[actingPlayerIndex],
                      isSubmitting: controller.isSubmittingAction.value,
                      isLoading: controller.isLoadingLegalActions.value,
                      onSubmit: controller.submitLegalAction,
                    ),
                  ],
                );
        }),
      ),
    );
  }

  Future<void> _showCardActions(SplendorCard card) {
    return CardActionsSheet.show(
      context: context,
      card: card,
      actions: controller.legalActions.value?.actions ?? const [],
      isSubmitting: controller.isSubmittingAction.value,
      onSubmit: controller.submitLegalAction,
    );
  }
}

/// 顶部对手摘要条。
class _OpponentStrip extends StatelessWidget {
  const _OpponentStrip({
    required this.players,
    required this.currentPlayerIndex,
    required this.cardsById,
  });

  final List<SplendorPlayerState> players;
  final int currentPlayerIndex;
  final Map<String, SplendorCard> cardsById;

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
            child: _CompactOpponentCard(player: player, cardsById: cardsById),
          ),
        );
      }).toList(),
    );
  }
}

/// 顶部紧凑对手卡。
class _CompactOpponentCard extends StatelessWidget {
  const _CompactOpponentCard({required this.player, required this.cardsById});

  final SplendorPlayerState player;
  final Map<String, SplendorCard> cardsById;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.secondary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showOpponentDetail(context),
        child: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.secondary.withValues(alpha: 0.2),
            ),
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
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14.w,
                    color: colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                  SizedBox(width: 4.w),
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
        ),
      ),
    );
  }

  void _showOpponentDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.76,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 20.h),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        player.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                SplendorPlayerAssetsPanel(
                  player: player,
                  cardsById: cardsById,
                  showTokens: true,
                  showReservedCards: true,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 当前回合提示。
class _TurnPrompt extends StatelessWidget {
  const _TurnPrompt({
    required this.turnIndex,
    required this.currentPlayer,
    required this.pendingAction,
  });

  final int turnIndex;
  final SplendorPlayerState currentPlayer;
  final SplendorPendingAction? pendingAction;

  @override
  Widget build(BuildContext context) {
    return Text(
      _promptText,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
      ),
    );
  }

  String get _promptText {
    final pendingAction = this.pendingAction;
    if (pendingAction == null) {
      return '第 ${turnIndex + 1} 回合，${currentPlayer.name} 请选择一项行动';
    }

    if (pendingAction.type == SplendorActionType.discardTokens) {
      final discardCount =
          (pendingAction.tokenCount ?? 0) - (pendingAction.maxTokenCount ?? 0);
      return '第 ${turnIndex + 1} 回合，${currentPlayer.name} 请先弃掉 $discardCount 个宝石';
    }

    return '第 ${turnIndex + 1} 回合，${currentPlayer.name} 请先处理待完成行动';
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
