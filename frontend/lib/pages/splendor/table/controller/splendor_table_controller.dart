import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../api/splendor_api.dart';
import '../../../../models/api_models.dart';
import '../../../../models/splendor_models.dart';

/// 璀璨宝石桌面页控制器。
///
/// 负责管理当前对局、catalog、刷新和后续行动提交所需的页面状态。
class SplendorTableController extends GetxController {
  /// 创建桌面页控制器。
  SplendorTableController({SplendorApi? splendorApi})
    : _splendorApi = splendorApi ?? SplendorApi();

  final SplendorApi _splendorApi;

  /// 当前对局快照。
  final Rxn<SplendorSessionResponse> sessionResponse =
      Rxn<SplendorSessionResponse>();

  /// 固定图鉴数据。
  final Rxn<SplendorCatalogResponse> catalog = Rxn<SplendorCatalogResponse>();

  /// 当前后端返回的合法行动。
  final Rxn<SplendorLegalActionsResponse> legalActions =
      Rxn<SplendorLegalActionsResponse>();

  /// 当前对局的行动历史记录。
  final RxList<SplendorActionRecord> actionHistory =
      <SplendorActionRecord>[].obs;

  /// 对局刷新中状态。
  final RxBool isRefreshing = false.obs;

  /// catalog 加载中状态。
  final RxBool isLoadingCatalog = false.obs;

  /// 合法行动加载中状态。
  final RxBool isLoadingLegalActions = false.obs;

  /// 行动历史加载中状态。
  final RxBool isLoadingActionHistory = false.obs;

  /// 行动提交中状态。
  final RxBool isSubmittingAction = false.obs;

  /// Bot 自动行动中状态。
  final RxBool isActingBot = false.obs;

  bool _isAutoAdvancingBot = false;

  /// 初始化桌面页所需数据。
  void initialize(SplendorSessionResponse? initialSessionResponse) {
    sessionResponse.value = initialSessionResponse;
    loadCatalog();
    loadLegalActions();
    loadActionHistory();
    _scheduleBotAutoAction();
  }

  /// 重新拉取 catalog，用于展示真实卡面信息。
  Future<void> loadCatalog() async {
    isLoadingCatalog.value = true;

    try {
      catalog.value = await _splendorApi.getCatalog();
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('读取卡牌数据失败，请确认后端服务已启动');
    } finally {
      isLoadingCatalog.value = false;
    }
  }

  /// 从后端重新拉取当前对局快照。
  Future<void> refreshSession() async {
    final sessionId = sessionResponse.value?.session.id;
    if (sessionId == null) {
      _showMessage('没有找到当前对局');
      return;
    }

    isRefreshing.value = true;

    try {
      sessionResponse.value = await _splendorApi.getSession(sessionId);
      await loadLegalActions();
      await loadActionHistory();
      _scheduleBotAutoAction();
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('刷新对局失败，请确认后端服务已启动');
    } finally {
      isRefreshing.value = false;
    }
  }

  /// 拉取当前玩家的合法行动列表。
  Future<void> loadLegalActions() async {
    final sessionId = sessionResponse.value?.session.id;
    if (sessionId == null) {
      return;
    }

    isLoadingLegalActions.value = true;

    try {
      final response = await _splendorApi.getLegalActions(sessionId);
      legalActions.value = response;
      _scheduleBotAutoAction();
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('读取合法行动失败，请确认后端服务已启动');
    } finally {
      isLoadingLegalActions.value = false;
    }
  }

  /// 拉取当前对局行动历史，用于用户回看每一步操作。
  Future<void> loadActionHistory() async {
    final sessionId = sessionResponse.value?.session.id;
    if (sessionId == null) {
      return;
    }

    isLoadingActionHistory.value = true;

    try {
      final response = await _splendorApi.getActions(sessionId);
      actionHistory.assignAll(response.actions);
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('读取行动历史失败，请确认后端服务已启动');
    } finally {
      isLoadingActionHistory.value = false;
    }
  }

  /// 提交一条后端返回的合法行动，并用返回的新状态刷新页面。
  Future<void> submitLegalAction(SplendorLegalAction legalAction) async {
    final session = sessionResponse.value;
    final playerIndex = legalActions.value?.playerIndex;
    if (session == null || playerIndex == null) {
      _showMessage('当前行动数据不完整');
      return;
    }
    final beforeState = session.state;
    final beforePlayer = session.state.players[playerIndex];

    isSubmittingAction.value = true;

    try {
      final response = await _splendorApi.submitAction(
        session.session.id,
        SplendorSubmitActionInput(
          playerIndex: playerIndex,
          action: legalAction.action,
          actorType: 'human',
        ),
      );
      sessionResponse.value = SplendorSessionResponse(
        session: response.session,
        players: session.players,
        state: response.state,
      );
      _showSubmittedActionMessage(
        legalAction: legalAction,
        playerName: beforePlayer.name,
      );
      _showAwardedNobleMessage(
        playerBefore: beforePlayer,
        playerAfter: response.state.players[playerIndex],
      );
      _showFinalRoundMessage(
        beforeState: beforeState,
        afterState: response.state,
      );
      _showGameFinishedMessage(
        beforeState: beforeState,
        afterState: response.state,
      );
      await loadLegalActions();
      await loadActionHistory();
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('提交行动失败，请确认后端服务已启动');
    } finally {
      isSubmittingAction.value = false;
      _scheduleBotAutoAction();
    }
  }

  /// 如果当前轮到 Bot，则延迟触发后端 Bot 自动行动。
  ///
  /// Bot 决策在后端完成，前端只负责在状态更新后继续检查下一个玩家是否仍是 Bot。
  void _scheduleBotAutoAction() {
    if (_isAutoAdvancingBot) {
      return;
    }
    final response = sessionResponse.value;
    if (response == null || !_shouldBotAct(response.state)) {
      return;
    }

    _isAutoAdvancingBot = true;
    Future<void>.delayed(const Duration(milliseconds: 600), () async {
      var acted = false;
      try {
        acted = await actCurrentBot();
      } finally {
        _isAutoAdvancingBot = false;
        if (acted) {
          _scheduleBotAutoAction();
        }
      }
    });
  }

  bool _shouldBotAct(SplendorGameState state) {
    if (state.status != SplendorSessionStatus.active) {
      return false;
    }
    if (isSubmittingAction.value || isActingBot.value) {
      return false;
    }
    if (state.currentPlayerIndex < 0 ||
        state.currentPlayerIndex >= state.players.length) {
      return false;
    }
    return state.players[state.currentPlayerIndex].type ==
        SplendorPlayerType.bot;
  }

  /// 调用后端让当前 Bot 玩家自动执行一个合法行动。
  Future<bool> actCurrentBot() async {
    final session = sessionResponse.value;
    if (session == null || !_shouldBotAct(session.state)) {
      developer.log(
        'skip bot action: session=${session?.session.id}, '
        'currentPlayer=${session?.state.currentPlayerIndex}, '
        'currentType=${_currentPlayerTypeName(session?.state)}',
        name: 'splendor.bot',
      );
      return false;
    }

    final beforeState = session.state;
    final beforePlayer = beforeState.players[beforeState.currentPlayerIndex];
    isActingBot.value = true;
    developer.log(
      'start bot action: session=${session.session.id}, '
      'turn=${beforeState.currentTurnIndex}, '
      'player=${beforePlayer.seatIndex}/${beforePlayer.name}, '
      'pending=${beforeState.pendingAction?.type.value}',
      name: 'splendor.bot',
    );

    try {
      final response = await _splendorApi.actBot(session.session.id);
      developer.log(
        'bot action success: session=${session.session.id}, '
        'selected=${response.decision.selectedAction.payload}, '
        'reason=${response.decision.reason}, '
        'nextPlayer=${response.state.currentPlayerIndex}',
        name: 'splendor.bot',
      );
      sessionResponse.value = SplendorSessionResponse(
        session: response.session,
        players: session.players,
        state: response.state,
      );
      _showMessage('${beforePlayer.name}：${response.decision.reason}');
      _showAwardedNobleMessage(
        playerBefore: beforePlayer,
        playerAfter: response.state.players[beforePlayer.seatIndex],
      );
      _showFinalRoundMessage(
        beforeState: beforeState,
        afterState: response.state,
      );
      _showGameFinishedMessage(
        beforeState: beforeState,
        afterState: response.state,
      );
      await loadLegalActions();
      await loadActionHistory();
      return true;
    } on ApiException catch (error) {
      developer.log(
        'bot action api error: code=${error.error.code}, '
        'message=${error.error.message}, session=${session.session.id}',
        name: 'splendor.bot',
        error: error,
      );
      _showMessage(error.error.message);
    } catch (error) {
      developer.log(
        'bot action unexpected error: session=${session.session.id}',
        name: 'splendor.bot',
        error: error,
      );
      _showMessage('Bot 行动失败：$error');
    } finally {
      isActingBot.value = false;
      if (sessionResponse.value != null) {
        _scheduleBotAutoAction();
      }
    }
    return false;
  }

  String? _currentPlayerTypeName(SplendorGameState? state) {
    if (state == null ||
        state.currentPlayerIndex < 0 ||
        state.currentPlayerIndex >= state.players.length) {
      return null;
    }
    return state.players[state.currentPlayerIndex].type.name;
  }

  void _showMessage(String message) {
    Get.snackbar(
      '璀璨宝石',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      duration: const Duration(seconds: 2),
    );
  }

  /// 根据提交行动类型显示轻量成功提示，不参与规则判断。
  void _showSubmittedActionMessage({
    required SplendorLegalAction legalAction,
    required String playerName,
  }) {
    final action = legalAction.action;
    final payload = action.payload;
    final message = switch (action.type) {
      SplendorActionType.takeTokens =>
        '$playerName 拿取了${_tokenText(payload['tokens'])}',
      SplendorActionType.reserveCard => '$playerName 预留了卡牌',
      SplendorActionType.buyCard =>
        '$playerName 购买了${_cardText(payload['cardId'] as String?)}',
      SplendorActionType.discardTokens =>
        '$playerName 弃掉了${_tokenText(payload['tokens'])}',
      SplendorActionType.chooseNoble => '$playerName 选择了贵族',
      SplendorActionType.nobleVisit => '$playerName 获得了贵族',
    };
    _showMessage(message);
  }

  /// 对比行动提交前后的玩家贵族列表，提示本回合自动获得的贵族。
  void _showAwardedNobleMessage({
    required SplendorPlayerState playerBefore,
    required SplendorPlayerState playerAfter,
  }) {
    final beforeNobleIds = playerBefore.nobles.toSet();
    final awardedNobleIds = playerAfter.nobles
        .where((nobleId) => !beforeNobleIds.contains(nobleId))
        .toList(growable: false);
    if (awardedNobleIds.isEmpty) {
      return;
    }

    final noble = _nobleById(awardedNobleIds.first);
    final nobleText = noble == null ? '贵族' : '${noble.prestige}分贵族';
    _showMessage('${playerAfter.name} 获得了$nobleText');
  }

  /// 对局首次触发终局轮时提示剩余玩家走完本轮后结算。
  void _showFinalRoundMessage({
    required SplendorGameState beforeState,
    required SplendorGameState afterState,
  }) {
    if (beforeState.finalRound.triggered || !afterState.finalRound.triggered) {
      return;
    }

    final triggeredBy = _playerName(
      afterState,
      afterState.finalRound.triggeredByPlayerIndex,
    );
    final roundEndPlayer = _playerName(
      afterState,
      afterState.finalRound.roundEndPlayerIndex,
    );
    _showMessage('$triggeredBy 达到 15 分，进入最后一轮，$roundEndPlayer 行动后结算');
  }

  /// 对局从进行中变成已结束时提示获胜玩家。
  void _showGameFinishedMessage({
    required SplendorGameState beforeState,
    required SplendorGameState afterState,
  }) {
    if (beforeState.status == SplendorSessionStatus.finished ||
        afterState.status != SplendorSessionStatus.finished) {
      return;
    }

    final winnerName = _playerName(afterState, afterState.winnerPlayerIndex);
    _showMessage('对局结束，$winnerName 获胜');
  }

  /// 从已加载 catalog 中按 ID 查找贵族，用于提交行动后的提示文案。
  SplendorNoble? _nobleById(String nobleId) {
    final nobles = catalog.value?.nobles;
    if (nobles == null) {
      return null;
    }

    for (final noble in nobles) {
      if (noble.id == nobleId) {
        return noble;
      }
    }
    return null;
  }

  String _playerName(SplendorGameState state, int? playerIndex) {
    if (playerIndex == null ||
        playerIndex < 0 ||
        playerIndex >= state.players.length) {
      return '玩家';
    }
    return state.players[playerIndex].name;
  }

  String _cardText(String? cardId) {
    if (cardId == null) {
      return '卡牌';
    }

    final cards = catalog.value?.cards;
    if (cards == null) {
      return '卡牌';
    }

    for (final card in cards) {
      if (card.id == cardId) {
        return '${_gemName(card.bonusColor)}色${card.prestige}分卡';
      }
    }
    return '卡牌';
  }

  String _tokenText(Object? value) {
    if (value is! Map<String, dynamic>) {
      return '宝石';
    }

    final entries = <String>[];
    for (final colorKey in ['white', 'blue', 'green', 'red', 'black', 'gold']) {
      final count = value[colorKey];
      if (count is int && count > 0) {
        entries.add('${_gemName(colorKey)}$count');
      }
    }

    return entries.isEmpty ? '宝石' : entries.join('、');
  }

  String _gemName(String colorKey) {
    return switch (colorKey) {
      'white' => '白',
      'blue' => '蓝',
      'green' => '绿',
      'red' => '红',
      'black' => '黑',
      'gold' => '金',
      _ => colorKey,
    };
  }
}
