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

  /// 对局刷新中状态。
  final RxBool isRefreshing = false.obs;

  /// catalog 加载中状态。
  final RxBool isLoadingCatalog = false.obs;

  /// 合法行动加载中状态。
  final RxBool isLoadingLegalActions = false.obs;

  /// 行动提交中状态。
  final RxBool isSubmittingAction = false.obs;

  /// 初始化桌面页所需数据。
  void initialize(SplendorSessionResponse? initialSessionResponse) {
    sessionResponse.value = initialSessionResponse;
    loadCatalog();
    loadLegalActions();
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
      _logLegalActions(response);
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('读取合法行动失败，请确认后端服务已启动');
    } finally {
      isLoadingLegalActions.value = false;
    }
  }

  void _logLegalActions(SplendorLegalActionsResponse response) {
    final state = sessionResponse.value?.state;
    final takeTokenActions = response.actions
        .where((item) => item.action.type == SplendorActionType.takeTokens)
        .map((item) => item.action.payload)
        .toList(growable: false);
    debugPrint(
      '[splendor legal-actions] '
      'playerIndex=${response.playerIndex}, '
      'pending=${response.pendingAction?.type.value}, '
      'tokenPool=${_tokenSetLabel(state?.tokenPool)}, '
      'playerTokens=${_tokenSetLabel(state?.players[response.playerIndex].tokens)}, '
      'takeTokenActions=$takeTokenActions',
    );
  }

  /// 提交一条后端返回的合法行动，并用返回的新状态刷新页面。
  Future<void> submitLegalAction(SplendorLegalAction legalAction) async {
    final session = sessionResponse.value;
    final playerIndex = legalActions.value?.playerIndex;
    if (session == null || playerIndex == null) {
      _showMessage('当前行动数据不完整');
      return;
    }

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
      await loadLegalActions();
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('提交行动失败，请确认后端服务已启动');
    } finally {
      isSubmittingAction.value = false;
    }
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
}

String _tokenSetLabel(SplendorTokenSet? tokens) {
  if (tokens == null) {
    return 'null';
  }
  return '{white:${tokens.white}, blue:${tokens.blue}, green:${tokens.green}, red:${tokens.red}, black:${tokens.black}, gold:${tokens.gold}}';
}
