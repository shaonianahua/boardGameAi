import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../models/api_models.dart';
import '../models/splendor_models.dart';
import '../shared/network/api_client.dart';
import 'api_config.dart';
import 'api_paths.dart';

/// 璀璨宝石 V1 接口封装。
///
/// 页面和控制器通过这个类调用后端；这里负责请求、响应解析和统一错误转换，
/// 不承载 UI 状态，也不实现游戏规则。
class SplendorApi {
  /// 可注入 `ApiClient` 方便测试；默认使用 `ApiConfig.defaultBaseUrl`。
  SplendorApi({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.defaultBaseUrl);

  final ApiClient _apiClient;

  /// 调用 `GET /health` 检查后端服务是否可用。
  Future<Map<String, dynamic>> health() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiPaths.health,
    );
    return _data(response);
  }

  /// 调用 `GET /api/splendor/catalog` 获取固定卡牌和贵族数据。
  Future<SplendorCatalogResponse> getCatalog() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiPaths.splendorCatalog,
    );
    return SplendorCatalogResponse.fromJson(_data(response));
  }

  /// 调用 `POST /api/splendor/sessions` 创建一局本地同屏对局。
  Future<SplendorSessionResponse> createSession(
    SplendorCreateSessionInput input,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiPaths.splendorSessions,
      data: input.toJson(),
    );
    return SplendorSessionResponse.fromJson(_data(response));
  }

  /// 调用 `GET /api/splendor/sessions/:sessionId` 获取对局快照。
  Future<SplendorSessionResponse> getSession(String sessionId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiPaths.splendorSession(sessionId),
    );
    return SplendorSessionResponse.fromJson(_data(response));
  }

  /// 调用 `GET /api/splendor/sessions/:sessionId/legal-actions` 获取当前合法行动。
  Future<SplendorLegalActionsResponse> getLegalActions(String sessionId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiPaths.splendorLegalActions(sessionId),
    );
    return SplendorLegalActionsResponse.fromJson(_data(response));
  }

  /// 调用 `POST /api/splendor/sessions/:sessionId/actions` 提交玩家行动。
  Future<SplendorSubmitActionResponse> submitAction(
    String sessionId,
    SplendorSubmitActionInput input,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiPaths.splendorActions(sessionId),
      data: input.toJson(),
    );
    return SplendorSubmitActionResponse.fromJson(_data(response));
  }

  /// 调用 `GET /api/splendor/sessions/:sessionId/actions` 获取对局操作记录。
  Future<SplendorActionsResponse> getActions(String sessionId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiPaths.splendorActions(sessionId),
    );
    return SplendorActionsResponse.fromJson(_data(response));
  }

  /// 调用 `POST /api/splendor/sessions/:sessionId/bot/act` 让当前 Bot 玩家自动行动。
  ///
  /// 后端负责从合法行动中选择并执行，前端只接收更新后的状态和 Bot 决策说明。
  Future<SplendorBotActionResponse> actBot(String sessionId) async {
    final response = await _request(
      () => _apiClient.post<Map<String, dynamic>>(
        ApiPaths.splendorBotAct(sessionId),
        data: const <String, dynamic>{},
      ),
    );
    return SplendorBotActionResponse.fromJson(_data(response));
  }

  /// 调用 `POST /api/splendor/sessions/:sessionId/ai/decide` 获取真人当前回合策略建议。
  ///
  /// 第一版只请求结构化建议，不执行行动；后续接入大模型或流式输出时仍从这里统一封装。
  Future<SplendorAiAdviceResponse> requestAiAdvice(String sessionId) async {
    final response = await _request(
      () => _apiClient.post<Map<String, dynamic>>(
        ApiPaths.splendorAiDecision(sessionId),
        data: const <String, dynamic>{},
      ),
    );
    return SplendorAiAdviceResponse.fromJson(_data(response));
  }

  /// 包装 Dio 请求，把后端非 2xx 错误体里的 `{ error }` 转成 `ApiException`。
  Future<Response<Map<String, dynamic>>> _request(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final data = error.response?.data;
      developer.log(
        'Dio request failed: status=${error.response?.statusCode}, '
        'type=${error.type}, data=$data',
        name: 'splendor.api',
        error: error,
        stackTrace: error.stackTrace,
      );
      if (data is Map<String, dynamic>) {
        final apiError = _errorFromData(data);
        if (apiError != null) {
          throw ApiException(apiError);
        }
      }
      throw ApiException(
        ApiError(
          code: error.type.name.toUpperCase(),
          message: error.message ?? 'network request failed',
        ),
      );
    }
  }

  /// 提取后端响应体，并把 `{ error: { code, message } }` 转成 `ApiException`。
  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) {
      throw const ApiException(
        ApiError(code: 'EMPTY_RESPONSE', message: 'empty response'),
      );
    }

    final error = data['error'];
    if (error is Map<String, dynamic>) {
      throw ApiException(ApiError.fromJson(error));
    }

    return data;
  }

  ApiError? _errorFromData(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      return ApiError.fromJson(error);
    }
    return null;
  }
}
