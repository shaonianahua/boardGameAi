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
}
