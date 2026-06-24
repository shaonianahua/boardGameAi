import 'dart:developer' as developer;

import 'package:get/get.dart';

import '../../../../api/splendor_api.dart';
import '../../../../models/api_models.dart';
import '../../../../models/splendor_models.dart';

/// 自动玩家行动完成后的结果。
///
/// 由自动玩家控制器返回给桌面主控制器，用于刷新对局状态和展示关键事件。
class SplendorAutoPlayerActResult {
  /// 构造自动玩家行动结果。
  const SplendorAutoPlayerActResult({
    required this.session,
    required this.state,
    required this.playerBefore,
    required this.fallbackToLocalBot,
  });

  /// 后端返回的更新后对局元信息。
  final SplendorSession session;

  /// 后端返回的更新后游戏状态。
  final SplendorGameState state;

  /// 自动玩家行动前的玩家状态，用于主控制器比较贵族、终局等变化。
  final SplendorPlayerState playerBefore;

  /// AI 玩家是否因为模型不可用而临时回退成本地 Bot。
  final bool fallbackToLocalBot;
}

/// 璀璨宝石自动玩家控制器。
///
/// 负责区分本地 Bot 与 AI 玩家，调用对应后端接口并管理自动行动中的状态。
class SplendorAutoPlayerController extends GetxController {
  /// 创建自动玩家控制器。
  SplendorAutoPlayerController({SplendorApi? splendorApi})
    : _splendorApi = splendorApi ?? SplendorApi();

  final SplendorApi _splendorApi;

  /// 当前是否正在执行本地 Bot 行动。
  final RxBool isActingLocalBot = false.obs;

  /// 当前是否正在执行 AI 玩家行动。
  final RxBool isActingAiPlayer = false.obs;

  /// 当前是否存在任意自动玩家行动中。
  bool get isActing => isActingLocalBot.value || isActingAiPlayer.value;

  /// 判断指定玩家是否是本地 Bot。
  bool isLocalBot(SplendorPlayerState player) {
    return player.type == SplendorPlayerType.bot &&
        SplendorBotLevel.fromJson(player.botLevel) == SplendorBotLevel.local;
  }

  /// 判断指定玩家是否是 AI 玩家。
  bool isAiPlayer(SplendorPlayerState player) {
    return player.type == SplendorPlayerType.bot &&
        SplendorBotLevel.fromJson(player.botLevel) == SplendorBotLevel.ai;
  }

  /// 判断当前状态是否轮到自动玩家行动。
  bool shouldAct(SplendorGameState state) {
    if (state.status != SplendorSessionStatus.active) {
      return false;
    }
    if (isActing) {
      return false;
    }
    if (state.currentPlayerIndex < 0 ||
        state.currentPlayerIndex >= state.players.length) {
      return false;
    }
    final player = state.players[state.currentPlayerIndex];
    return isLocalBot(player) || isAiPlayer(player);
  }

  /// 调用对应后端接口，让当前自动玩家执行一个合法行动。
  Future<SplendorAutoPlayerActResult?> actCurrentPlayer({
    required String sessionId,
    required SplendorGameState state,
  }) async {
    if (!shouldAct(state)) {
      developer.log(
        'skip auto player action: session=$sessionId, '
        'currentPlayer=${state.currentPlayerIndex}',
        name: 'splendor.auto-player',
      );
      return null;
    }

    final playerBefore = state.players[state.currentPlayerIndex];
    if (isAiPlayer(playerBefore)) {
      return _actAiPlayer(sessionId: sessionId, playerBefore: playerBefore);
    }
    return _actLocalBot(sessionId: sessionId, playerBefore: playerBefore);
  }

  /// 调用本地 Bot 自动行动接口。
  Future<SplendorAutoPlayerActResult?> _actLocalBot({
    required String sessionId,
    required SplendorPlayerState playerBefore,
  }) async {
    isActingLocalBot.value = true;
    developer.log(
      'start local bot action: session=$sessionId, '
      'player=${playerBefore.seatIndex}/${playerBefore.name}',
      name: 'splendor.auto-player',
    );

    try {
      final response = await _splendorApi.actBot(sessionId);
      developer.log(
        'local bot action success: session=$sessionId, '
        'selected=${response.decision.selectedAction.payload}, '
        'reason=${response.decision.reason}',
        name: 'splendor.auto-player',
      );
      return SplendorAutoPlayerActResult(
        session: response.session,
        state: response.state,
        playerBefore: playerBefore,
        fallbackToLocalBot: false,
      );
    } on ApiException catch (error) {
      developer.log(
        'local bot action api error: code=${error.error.code}, '
        'message=${error.error.message}, session=$sessionId',
        name: 'splendor.auto-player',
        error: error,
      );
      rethrow;
    } catch (error) {
      developer.log(
        'local bot action unexpected error: session=$sessionId',
        name: 'splendor.auto-player',
        error: error,
      );
      rethrow;
    } finally {
      isActingLocalBot.value = false;
    }
  }

  /// 调用 AI 玩家自动行动接口；模型失败时后端会回退本地 Bot。
  Future<SplendorAutoPlayerActResult?> _actAiPlayer({
    required String sessionId,
    required SplendorPlayerState playerBefore,
  }) async {
    isActingAiPlayer.value = true;
    developer.log(
      'start ai player action: session=$sessionId, '
      'player=${playerBefore.seatIndex}/${playerBefore.name}',
      name: 'splendor.auto-player',
    );

    try {
      final response = await _splendorApi.actAiPlayer(sessionId);
      developer.log(
        'ai player action success: session=$sessionId, '
        'actionId=${response.advice.decision.actionId}, '
        'fallback=${response.fallbackToLocalBot}, '
        'summary=${response.advice.decision.summary}',
        name: 'splendor.auto-player',
      );
      return SplendorAutoPlayerActResult(
        session: response.session,
        state: response.state,
        playerBefore: playerBefore,
        fallbackToLocalBot: response.fallbackToLocalBot,
      );
    } on ApiException catch (error) {
      developer.log(
        'ai player action api error: code=${error.error.code}, '
        'message=${error.error.message}, session=$sessionId',
        name: 'splendor.auto-player',
        error: error,
      );
      rethrow;
    } catch (error) {
      developer.log(
        'ai player action unexpected error: session=$sessionId',
        name: 'splendor.auto-player',
        error: error,
      );
      rethrow;
    } finally {
      isActingAiPlayer.value = false;
    }
  }
}
