import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../models/splendor_models.dart';
import 'table/actions/card_actions_sheet.dart';
import 'table/actions/legal_actions_panel.dart';
import 'table/controller/splendor_table_controller.dart';
import 'table/splendor_catalog_lookup.dart';
import 'table/widgets/splendor_action_history_panel.dart';
import 'table/widgets/splendor_ai_advice_panel.dart';
import 'table/widgets/splendor_game_result_panel.dart';
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
              tooltip: '行动历史',
              onPressed: controller.sessionResponse.value == null
                  ? null
                  : _showActionHistorySheet,
              icon: controller.isLoadingActionHistory.value
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.history_rounded),
            ),
          ),
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
          final hiddenReservedCardIdsByPlayer = _hiddenReservedCardIdsByPlayer(
            players: response?.state.players ?? const [],
            actions: controller.actionHistory,
            hideAllReservedCards: controller.isLoadingActionHistory.value,
          );

          return response == null
              ? const _EmptySessionView()
              : ListView(
                  padding: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 14.h),
                  children: [
                    _OpponentStrip(
                      players: response.state.players,
                      currentPlayerIndex: response.state.currentPlayerIndex,
                      cardsById: lookup.cardsById,
                      hiddenReservedCardIdsByPlayer:
                          hiddenReservedCardIdsByPlayer,
                    ),
                    SizedBox(height: 8.h),
                    SplendorMarketCard(
                      markets: response.state.markets,
                      cardsById: lookup.cardsById,
                      isLoadingCatalog: controller.isLoadingCatalog.value,
                      onCardSelected: _showCardActions,
                      legalActions: controller.legalActions.value,
                      isSubmitting:
                          controller.isSubmittingAction.value ||
                          controller.isActingBot.value,
                      onSubmit: controller.submitLegalAction,
                    ),
                    SizedBox(height: 8.h),
                    SplendorTokenPoolCard(
                      tokenPool: response.state.tokenPool,
                      legalActions: controller.legalActions.value,
                      isLoadingLegalActions:
                          controller.isLoadingLegalActions.value,
                      isSubmitting:
                          controller.isSubmittingAction.value ||
                          controller.isActingBot.value,
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
                      isActingBot: controller.isActingBot.value,
                    ),
                    if (_canShowAiAdviceButton(response.state)) ...[
                      SizedBox(height: 8.h),
                      _AiAdviceButton(
                        isLoading: controller.isLoadingAiAdvice.value,
                        isDisabled:
                            controller.isSubmittingAction.value ||
                            controller.isActingBot.value,
                        onPressed: _showAiAdviceSheet,
                      ),
                    ],
                    SizedBox(height: 8.h),
                    SplendorGameResultPanel(state: response.state),
                    if (response.state.finalRound.triggered ||
                        response.state.status == SplendorSessionStatus.finished)
                      SizedBox(height: 8.h),
                    SplendorPlayerSummaryCard(
                      player: response
                          .state
                          .players[response.state.currentPlayerIndex],
                      isCurrent: true,
                      cardsById: lookup.cardsById,
                      onReservedCardSelected: _showReservedCardActions,
                    ),
                    SizedBox(height: 8.h),
                    LegalActionsPanel(
                      legalActions: legalActions,
                      currentPlayer: response.state.players[actingPlayerIndex],
                      isSubmitting:
                          controller.isSubmittingAction.value ||
                          controller.isActingBot.value,
                      isActingBot: controller.isActingBot.value,
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

  Future<void> _showReservedCardActions(SplendorCard card) {
    return CardActionsSheet.show(
      context: context,
      card: card,
      source: 'reserved',
      actions: controller.legalActions.value?.actions ?? const [],
      isSubmitting: controller.isSubmittingAction.value,
      onSubmit: controller.submitLegalAction,
    );
  }

  Future<void> _showActionHistorySheet() async {
    await controller.loadActionHistory();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.74,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Obx(() {
              final response = controller.sessionResponse.value;
              final lookup = SplendorCatalogLookup(controller.catalog.value);

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 10.h, 8.w, 4.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '行动历史',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          tooltip: '刷新历史',
                          onPressed: controller.isLoadingActionHistory.value
                              ? null
                              : controller.loadActionHistory,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: response == null
                        ? const Center(child: Text('没有找到当前对局。'))
                        : SplendorActionHistoryPanel(
                            actions: controller.actionHistory,
                            players: response.state.players,
                            cardsById: lookup.cardsById,
                            noblesById: lookup.noblesById,
                            isLoading: controller.isLoadingActionHistory.value,
                            scrollController: scrollController,
                          ),
                  ),
                ],
              );
            });
          },
        );
      },
    );
  }

  bool _canShowAiAdviceButton(SplendorGameState state) {
    if (state.status != SplendorSessionStatus.active) {
      return false;
    }
    final currentPlayer = state.players[state.currentPlayerIndex];
    return currentPlayer.type == SplendorPlayerType.human;
  }

  Future<void> _showAiAdviceSheet() async {
    final advice = await controller.requestAiAdvice();
    if (!mounted || advice == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.68,
          minChildSize: 0.38,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Obx(() {
              final currentAdvice = controller.aiAdvice.value ?? advice;
              return SplendorAiAdvicePanel(
                advice: currentAdvice,
                scrollController: scrollController,
                onClose: () => Navigator.of(context).pop(),
              );
            });
          },
        );
      },
    );
  }
}

/// 根据行动历史找出每个玩家从牌堆盲抽预留的隐藏卡。
///
/// 后端当前状态只保存 reserved card ID，本方法通过行动前后状态差异识别
/// `reserve_card source: deck` 新增的卡，供对手详情隐藏卡面。
Map<int, Set<String>> _hiddenReservedCardIdsByPlayer({
  required List<SplendorPlayerState> players,
  required List<SplendorActionRecord> actions,
  required bool hideAllReservedCards,
}) {
  if (hideAllReservedCards) {
    return {
      for (final player in players)
        player.seatIndex: player.reservedCards.toSet(),
    };
  }

  final hiddenIdsByPlayer = <int, Set<String>>{};
  for (final record in actions) {
    final action = record.action;
    final payload = action.payload;
    if (action.type != SplendorActionType.reserveCard ||
        payload['source'] != 'deck') {
      continue;
    }

    final playerIndex = record.playerIndex;
    final beforePlayer = _playerAt(record.stateBefore.players, playerIndex);
    final afterPlayer = _playerAt(record.stateAfter.players, playerIndex);
    if (beforePlayer == null || afterPlayer == null) {
      continue;
    }

    final beforeReservedIds = beforePlayer.reservedCards.toSet();
    final addedReservedIds = afterPlayer.reservedCards.where(
      (cardId) => !beforeReservedIds.contains(cardId),
    );
    hiddenIdsByPlayer
        .putIfAbsent(playerIndex, () => <String>{})
        .addAll(addedReservedIds);
  }

  return hiddenIdsByPlayer;
}

SplendorPlayerState? _playerAt(List<SplendorPlayerState> players, int index) {
  if (index < 0 || index >= players.length) {
    return null;
  }
  return players[index];
}

/// 顶部对手摘要条。
class _OpponentStrip extends StatelessWidget {
  const _OpponentStrip({
    required this.players,
    required this.currentPlayerIndex,
    required this.cardsById,
    required this.hiddenReservedCardIdsByPlayer,
  });

  final List<SplendorPlayerState> players;
  final int currentPlayerIndex;
  final Map<String, SplendorCard> cardsById;
  final Map<int, Set<String>> hiddenReservedCardIdsByPlayer;

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
            child: _CompactOpponentCard(
              player: player,
              cardsById: cardsById,
              hiddenReservedCardIds:
                  hiddenReservedCardIdsByPlayer[player.seatIndex] ??
                  const <String>{},
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 顶部紧凑对手卡。
class _CompactOpponentCard extends StatelessWidget {
  const _CompactOpponentCard({
    required this.player,
    required this.cardsById,
    required this.hiddenReservedCardIds,
  });

  final SplendorPlayerState player;
  final Map<String, SplendorCard> cardsById;
  final Set<String> hiddenReservedCardIds;

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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (player.type == SplendorPlayerType.bot) ...[
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.smart_toy_rounded,
                            size: 13.w,
                            color: colorScheme.primary,
                          ),
                        ],
                      ],
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
                  hiddenReservedCardIds: hiddenReservedCardIds,
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
    required this.isActingBot,
  });

  final int turnIndex;
  final SplendorPlayerState currentPlayer;
  final SplendorPendingAction? pendingAction;
  final bool isActingBot;

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
      if (currentPlayer.type == SplendorPlayerType.bot) {
        return isActingBot
            ? '第 ${turnIndex + 1} 回合，${currentPlayer.name} 正在思考'
            : '第 ${turnIndex + 1} 回合，等待 ${currentPlayer.name} 自动行动';
      }
      return '第 ${turnIndex + 1} 回合，${currentPlayer.name} 请选择一项行动';
    }

    if (pendingAction.type == SplendorActionType.discardTokens) {
      final discardCount =
          (pendingAction.tokenCount ?? 0) - (pendingAction.maxTokenCount ?? 0);
      if (currentPlayer.type == SplendorPlayerType.bot) {
        return '第 ${turnIndex + 1} 回合，${currentPlayer.name} 正在弃掉 $discardCount 个宝石';
      }
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

/// 真人回合的 AI 建议入口按钮。
class _AiAdviceButton extends StatelessWidget {
  const _AiAdviceButton({
    required this.isLoading,
    required this.isDisabled,
    required this.onPressed,
  });

  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading || isDisabled ? null : onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16.w,
              height: 16.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome_rounded),
      label: Text(isLoading ? '正在分析' : 'AI 建议'),
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
