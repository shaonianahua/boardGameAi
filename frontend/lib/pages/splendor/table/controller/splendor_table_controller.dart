import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../api/splendor_api.dart';
import '../../../../models/api_models.dart';
import '../../../../models/splendor_models.dart';
import 'splendor_auto_player_controller.dart';

/// 璀璨宝石桌面页控制器。
///
/// 负责管理当前对局、catalog、刷新和后续行动提交所需的页面状态。
class SplendorTableController extends GetxController {
  /// 创建桌面页控制器。
  SplendorTableController({
    SplendorApi? splendorApi,
    SplendorAutoPlayerController? autoPlayerController,
  }) : _splendorApi = splendorApi ?? SplendorApi(),
       autoPlayerController =
           autoPlayerController ?? SplendorAutoPlayerController();

  final SplendorApi _splendorApi;

  /// 自动玩家控制器，负责本地 Bot 与 AI 玩家自动行动。
  final SplendorAutoPlayerController autoPlayerController;

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

  /// AI 建议请求中状态。
  final RxBool isLoadingAiAdvice = false.obs;

  /// 最近一次 AI 建议结果，用于底部策略面板展示。
  final Rxn<SplendorAiAdviceResponse> aiAdvice =
      Rxn<SplendorAiAdviceResponse>();

  /// AI 建议流式输出文本，供底部策略面板做渐进展示。
  final RxList<String> aiAdviceStreamLines = <String>[].obs;

  static const _maxAiAdviceStreamRetries = 3;

  bool _isAutoAdvancingPlayer = false;

  /// 初始化桌面页所需数据。
  void initialize(SplendorSessionResponse? initialSessionResponse) {
    sessionResponse.value = initialSessionResponse;
    loadCatalog();
    loadLegalActions();
    loadActionHistory();
    _scheduleAutoPlayerAction();
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
      _scheduleAutoPlayerAction();
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
      _scheduleAutoPlayerAction();
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
    await _submitLegalAction(legalAction);
  }

  /// 提交合法行动并返回是否成功，供 AI 推荐执行后清理旧建议使用。
  Future<bool> _submitLegalAction(SplendorLegalAction legalAction) async {
    final session = sessionResponse.value;
    final playerIndex = legalActions.value?.playerIndex;
    if (session == null || playerIndex == null) {
      _showMessage('当前行动数据不完整');
      return false;
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
      return true;
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('提交行动失败，请确认后端服务已启动');
    } finally {
      isSubmittingAction.value = false;
      _scheduleAutoPlayerAction();
    }
    return false;
  }

  /// 如果当前轮到自动玩家，则延迟触发后端自动行动。
  ///
  /// 自动玩家决策在后端完成，前端只负责刷新状态并继续检查连续自动玩家。
  void _scheduleAutoPlayerAction() {
    if (_isAutoAdvancingPlayer) {
      return;
    }
    final response = sessionResponse.value;
    if (response == null || !_shouldAutoPlayerAct(response.state)) {
      return;
    }

    _isAutoAdvancingPlayer = true;
    Future<void>.delayed(const Duration(milliseconds: 600), () async {
      var acted = false;
      try {
        acted = await actCurrentAutoPlayer();
      } finally {
        _isAutoAdvancingPlayer = false;
        if (acted) {
          _scheduleAutoPlayerAction();
        }
      }
    });
  }

  /// 判断当前状态是否满足自动玩家行动条件。
  ///
  /// 只有没有真人提交且自动玩家控制器空闲时才会触发。
  bool _shouldAutoPlayerAct(SplendorGameState state) {
    if (isSubmittingAction.value) {
      return false;
    }
    return autoPlayerController.shouldAct(state);
  }

  /// 调用后端让当前自动玩家执行一个合法行动。
  Future<bool> actCurrentAutoPlayer() async {
    final session = sessionResponse.value;
    if (session == null || !_shouldAutoPlayerAct(session.state)) {
      developer.log(
        'skip auto player action: session=${session?.session.id}, '
        'currentPlayer=${session?.state.currentPlayerIndex}, '
        'currentType=${_currentPlayerTypeName(session?.state)}',
        name: 'splendor.auto-player',
      );
      return false;
    }

    final beforeState = session.state;
    developer.log(
      'start auto player action: session=${session.session.id}, '
      'turn=${beforeState.currentTurnIndex}, '
      'player=${beforeState.currentPlayerIndex}, '
      'pending=${beforeState.pendingAction?.type.value}',
      name: 'splendor.auto-player',
    );

    try {
      final result = await autoPlayerController.actCurrentPlayer(
        sessionId: session.session.id,
        state: session.state,
      );
      if (result == null) {
        return false;
      }
      developer.log(
        'auto player action success: session=${session.session.id}, '
        'nextPlayer=${result.state.currentPlayerIndex}, '
        'fallback=${result.fallbackToLocalBot}',
        name: 'splendor.auto-player',
      );
      sessionResponse.value = SplendorSessionResponse(
        session: result.session,
        players: session.players,
        state: result.state,
      );
      _showAwardedNobleMessage(
        playerBefore: result.playerBefore,
        playerAfter: result.state.players[result.playerBefore.seatIndex],
      );
      _showFinalRoundMessage(
        beforeState: beforeState,
        afterState: result.state,
      );
      _showGameFinishedMessage(
        beforeState: beforeState,
        afterState: result.state,
      );
      await loadLegalActions();
      await loadActionHistory();
      return true;
    } on ApiException catch (error) {
      developer.log(
        'auto player action api error: code=${error.error.code}, '
        'message=${error.error.message}, session=${session.session.id}',
        name: 'splendor.auto-player',
        error: error,
      );
      _showMessage(error.error.message);
    } catch (error) {
      developer.log(
        'auto player action unexpected error: session=${session.session.id}',
        name: 'splendor.auto-player',
        error: error,
      );
      _showMessage('自动玩家行动失败：$error');
    } finally {
      if (sessionResponse.value != null) {
        _scheduleAutoPlayerAction();
      }
    }
    return false;
  }

  /// 为当前真人玩家请求一份 AI 策略建议，优先使用流式接口。
  ///
  /// 流式失败时回退非流式接口；这里只更新展示状态，不执行推荐行动。
  Future<SplendorAiAdviceResponse?> requestAiAdvice() async {
    final session = sessionResponse.value;
    if (session == null) {
      _showMessage('没有找到当前对局');
      return null;
    }
    if (session.state.status != SplendorSessionStatus.active) {
      _showMessage('对局已结束，不能继续请求建议');
      return null;
    }

    final currentPlayer =
        session.state.players[session.state.currentPlayerIndex];
    if (currentPlayer.type != SplendorPlayerType.human) {
      _showMessage('当前是 Bot 回合，暂时不需要 AI 建议');
      return null;
    }

    isLoadingAiAdvice.value = true;
    aiAdviceStreamLines.clear();
    try {
      developer.log(
        'start ai advice stream: session=${session.session.id}, '
        'turn=${session.state.currentTurnIndex}, '
        'player=${currentPlayer.seatIndex}/${currentPlayer.name}',
        name: 'splendor.ai',
      );

      final finalResponse = await _requestAiAdviceStreamWithRetry(
        session.session.id,
      );

      if (finalResponse == null) {
        throw const ApiException(
          ApiError(code: 'EMPTY_AI_STREAM', message: 'AI 流式建议没有返回结果'),
        );
      }

      developer.log(
        'ai advice stream success: session=${session.session.id}, '
        'actionId=${finalResponse.decision.actionId}, '
        'confidence=${finalResponse.decision.confidence}, '
        'selected=${finalResponse.selectedAction?.action.payload}, '
        'fallback=${_isHeuristicFallback(finalResponse)}, '
        'summary=${finalResponse.decision.summary}, '
        'lines=${aiAdviceStreamLines.length}',
        name: 'splendor.ai',
      );
      return finalResponse;
    } catch (error) {
      developer.log(
        'ai advice stream unexpected error: session=${session.session.id}',
        name: 'splendor.api',
        error: error,
      );
      _appendAiAdviceStreamText(
        'AI 建议生成异常，已停止生成。请稍后重新获取建议。',
        appendToLastLine: false,
      );
      _showMessage('AI 建议生成异常，请稍后重试');
      return null;
    } finally {
      isLoadingAiAdvice.value = false;
    }
  }

  /// 执行当前 AI 建议中的推荐行动。
  ///
  /// 提交前会校验该行动仍在当前合法行动列表中，避免局面变化后执行过期建议。
  Future<void> executeAiRecommendedAction() async {
    final recommendedAction = aiAdvice.value?.selectedAction;
    if (recommendedAction == null) {
      _showMessage('当前没有可执行的 AI 推荐行动');
      return;
    }
    if (isLoadingAiAdvice.value) {
      _showMessage('AI 建议还在生成中，请稍后再执行');
      return;
    }

    final matchedAction = _findMatchingLegalAction(recommendedAction);
    if (matchedAction == null) {
      _showMessage('推荐行动已不适用于当前局面，请重新获取 AI 建议');
      return;
    }

    final executed = await _submitLegalAction(matchedAction);
    if (!executed) {
      return;
    }

    aiAdvice.value = null;
    aiAdviceStreamLines.clear();
    _showMessage('已执行 AI 推荐行动');
  }

  /// 从当前合法行动中查找和 AI 推荐行动完全一致的一项。
  SplendorLegalAction? _findMatchingLegalAction(
    SplendorLegalAction recommendedAction,
  ) {
    final actions =
        legalActions.value?.actions ?? const <SplendorLegalAction>[];
    for (final legalAction in actions) {
      if (_isSameActionPayload(
        legalAction.action.payload,
        recommendedAction.action.payload,
      )) {
        return legalAction;
      }
    }
    return null;
  }

  /// 对比两个 action payload 是否一致，支持嵌套 Map/List 的深度比较。
  bool _isSameActionPayload(Object? left, Object? right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) {
        return false;
      }
      for (final entry in left.entries) {
        if (!right.containsKey(entry.key) ||
            !_isSameActionPayload(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) {
        return false;
      }
      for (var index = 0; index < left.length; index += 1) {
        if (!_isSameActionPayload(left[index], right[index])) {
          return false;
        }
      }
      return true;
    }
    return left == right;
  }

  /// 请求 AI 流式建议并在网络中断时自动重试。
  ///
  /// 重试会保留旧的流式文本，并在重新连接后提示后续内容为重新生成。
  Future<SplendorAiAdviceResponse?> _requestAiAdviceStreamWithRetry(
    String sessionId,
  ) async {
    for (var attempt = 0; attempt <= _maxAiAdviceStreamRetries; attempt += 1) {
      if (attempt > 0) {
        _appendAiAdviceStreamText('已重新连接，以下为重新生成内容。', appendToLastLine: false);
      }

      try {
        return await _consumeAiAdviceStream(sessionId);
      } on ApiException catch (error) {
        developer.log(
          'ai advice stream api error: code=${error.error.code}, '
          'message=${error.error.message}, session=$sessionId, attempt=$attempt',
          name: 'splendor.api',
          error: error,
        );
        if (!_isNetworkInterrupted(error)) {
          return _requestAiAdviceFallback(sessionId);
        }
        if (attempt >= _maxAiAdviceStreamRetries) {
          _appendAiAdviceStreamText(
            '网络连接仍然不可用，已停止自动重试。请检查网络或后端服务后重新获取建议。',
            appendToLastLine: false,
          );
          _showMessage(error.error.message);
          return null;
        }

        final retryDelay = _aiAdviceRetryDelay(attempt);
        _appendAiAdviceStreamText(
          '网络连接中断，${retryDelay.inSeconds} 秒后自动重试（${attempt + 1}/$_maxAiAdviceStreamRetries）。',
          appendToLastLine: false,
        );
        await Future<void>.delayed(retryDelay);
      }
    }

    return null;
  }

  /// 消费 AI 建议 SSE 事件流，实时更新展示文本并保存最终结构化结果。
  ///
  /// `delta` 事件用于渐进展示，`result` 事件用于更新 `aiAdvice`。
  Future<SplendorAiAdviceResponse?> _consumeAiAdviceStream(
    String sessionId,
  ) async {
    final streamDisplayFilter = _AiAdviceStreamDisplayFilter();
    SplendorAiAdviceResponse? finalResponse;

    await for (final event in _splendorApi.requestAiAdviceStream(sessionId)) {
      final visibleText = switch (event.type) {
        'delta' => streamDisplayFilter.append(event.text),
        _ => event.text,
      };
      if (visibleText.trim().isNotEmpty) {
        _appendAiAdviceStreamText(
          visibleText,
          appendToLastLine: event.type == 'delta',
        );
      }
      if (event.type == 'result') {
        streamDisplayFilter.stop();
      }
      if (event.type == 'done') {
        final flushedText = streamDisplayFilter.flush();
        if (flushedText.trim().isNotEmpty) {
          aiAdviceStreamLines.add(flushedText);
        }
      }
      if (event.text.isNotEmpty) {
        developer.log(
          'ai stream event: type=${event.type}, visible=${visibleText.isNotEmpty}, raw=${event.text}',
          name: 'splendor.ai',
        );
      }
      if (event.response != null) {
        finalResponse = event.response;
        aiAdvice.value = event.response;
      }
    }

    return finalResponse;
  }

  /// 根据重试次数计算 AI 流式建议的指数退避时间。
  Duration _aiAdviceRetryDelay(int attempt) {
    return Duration(seconds: 1 << attempt);
  }

  /// 流式接口不可用时请求非流式建议，作为兼容兜底方案。
  Future<SplendorAiAdviceResponse?> _requestAiAdviceFallback(
    String sessionId,
  ) async {
    try {
      aiAdviceStreamLines.add('流式建议暂不可用，正在切换为完整建议。');
      final response = await _splendorApi.requestAiAdvice(sessionId);
      aiAdvice.value = response;
      aiAdviceStreamLines.add('完整建议已返回。');
      return response;
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (error) {
      _showMessage('获取 AI 建议失败：$error');
    }
    return null;
  }

  /// 判断 AI 流式错误是否属于可自动重试的网络中断类问题。
  bool _isNetworkInterrupted(ApiException error) {
    return switch (error.error.code) {
      'NETWORK_INTERRUPTED' ||
      'AI_STREAM_READ_FAILED' ||
      'REQUEST_CANCELLED' ||
      'BAD_CERTIFICATE' => true,
      _ => false,
    };
  }

  /// 追加或拼接 AI 流式展示文本，供底部建议面板实时刷新。
  void _appendAiAdviceStreamText(
    String text, {
    required bool appendToLastLine,
  }) {
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) {
      return;
    }
    if (!appendToLastLine || aiAdviceStreamLines.isEmpty) {
      aiAdviceStreamLines.add(cleanedText);
      return;
    }

    aiAdviceStreamLines[aiAdviceStreamLines.length - 1] =
        '${aiAdviceStreamLines.last}$cleanedText';
  }

  /// 判断 AI 建议是否由后端本地启发式兜底生成。
  bool _isHeuristicFallback(SplendorAiAdviceResponse response) {
    return response.decision.reasoning.any(
      (reason) => reason.contains('模型建议暂不可用') || reason.contains('回退本地启发式'),
    );
  }

  /// 获取当前玩家类型名称，用于 Bot 调试日志。
  String? _currentPlayerTypeName(SplendorGameState? state) {
    if (state == null ||
        state.currentPlayerIndex < 0 ||
        state.currentPlayerIndex >= state.players.length) {
      return null;
    }
    return state.players[state.currentPlayerIndex].type.name;
  }

  /// 在桌面页顶部展示轻量提示，避免遮挡底部行动区域。
  void _showMessage(String message) {
    Get.snackbar(
      '璀璨宝石',
      message,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      duration: const Duration(seconds: 2),
    );
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

  /// 根据玩家下标获取展示名称；下标无效时返回通用“玩家”。
  String _playerName(SplendorGameState state, int? playerIndex) {
    if (playerIndex == null ||
        playerIndex < 0 ||
        playerIndex >= state.players.length) {
      return '玩家';
    }
    return state.players[playerIndex].name;
  }
}

/// AI 流式文本展示过滤器。
///
/// 模型原生流可能把 `<FINAL_JSON>` 和 JSON 片段拆成多个 chunk 返回；
/// 这些内容只用于后端解析结构化建议，不应该直接展示给用户。
class _AiAdviceStreamDisplayFilter {
  static const _finalJsonMarkerStart = '<FINAL_JSON';
  static const _finalJsonMarker = '<FINAL_JSON>';
  static const _markerLookbehind = 20;

  final StringBuffer _buffer = StringBuffer();
  bool _stopped = false;

  /// 接收一个模型 delta chunk，返回可以展示给用户的安全文本。
  ///
  /// 发现 `<FINAL_JSON>` 后会停止输出，避免结构化 JSON 泄露到 UI。
  String append(String chunk) {
    if (_stopped || chunk.isEmpty) {
      return '';
    }

    _buffer.write(chunk);
    final text = _buffer.toString();
    final markerIndex = text.indexOf(_finalJsonMarkerStart);
    if (markerIndex >= 0) {
      _stopped = true;
      _buffer.clear();
      return _cleanVisibleText(text.substring(0, markerIndex));
    }

    final safeLength = text.length - _markerLookbehind;
    if (safeLength <= 0) {
      return '';
    }

    final visible = text.substring(0, safeLength);
    _buffer
      ..clear()
      ..write(text.substring(safeLength));
    return _cleanVisibleText(visible);
  }

  /// 在流结束时吐出缓冲区剩余文本，已经进入 JSON 段时返回空字符串。
  String flush() {
    if (_stopped) {
      _buffer.clear();
      return '';
    }
    final visible = _cleanVisibleText(_buffer.toString());
    _buffer.clear();
    return visible;
  }

  /// 手动停止文本输出，并清空尚未展示的缓冲内容。
  void stop() {
    _stopped = true;
    _buffer.clear();
  }

  /// 清理模型输出中的 JSON 标记和代码块标记，只保留自然语言展示内容。
  String _cleanVisibleText(String text) {
    final cleanedText = text
        .replaceAll('</FINAL_JSON>', '')
        .replaceAll(_finalJsonMarker, '')
        .replaceAll(_finalJsonMarkerStart, '')
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    if (_looksLikeJsonFragment(cleanedText)) {
      return '';
    }
    return cleanedText;
  }

  /// 粗略判断文本是否像最终 JSON 片段，防止半截结构化内容显示到面板。
  bool _looksLikeJsonFragment(String text) {
    if (text.isEmpty) {
      return false;
    }
    final trimmedText = text.trimLeft();
    return trimmedText.startsWith('{') ||
        trimmedText.startsWith('"actionId"') ||
        trimmedText.startsWith('"confidence"') ||
        trimmedText.startsWith('"summary"') ||
        trimmedText.startsWith('"reasoning"') ||
        trimmedText.startsWith('"alternatives"') ||
        trimmedText.startsWith('"threats"') ||
        trimmedText.startsWith('"risks"');
  }
}
