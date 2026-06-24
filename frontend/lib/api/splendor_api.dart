import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
  static const _streamLogName = 'splendor.ai.stream';

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

  /// 调用 `POST /api/splendor/sessions/:sessionId/ai/act` 让当前 AI 玩家自动行动。
  ///
  /// 后端会调用模型在合法行动中选择；模型失败时会回退本地 Bot 并返回 fallback 标记。
  Future<SplendorAiPlayerActionResponse> actAiPlayer(String sessionId) async {
    final response = await _request(
      () => _apiClient.post<Map<String, dynamic>>(
        ApiPaths.splendorAiAct(sessionId),
        data: const <String, dynamic>{},
      ),
    );
    return SplendorAiPlayerActionResponse.fromJson(_data(response));
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

  /// 调用 `POST /api/splendor/sessions/:sessionId/ai/stream` 获取 AI 流式建议事件。
  ///
  /// 返回事件包括 progress、delta、result 和 done；result 事件携带最终结构化建议。
  Stream<SplendorAiAdviceStreamEvent> requestAiAdviceStream(
    String sessionId,
  ) async* {
    try {
      final textStream = await _apiClient.postTextStream(
        ApiPaths.splendorAiStream(sessionId),
        data: const <String, dynamic>{},
        options: Options(headers: const {'Accept': 'text/event-stream'}),
      );

      _streamLog('start stream session=$sessionId');
      final buffer = StringBuffer();
      await for (final chunk in textStream) {
        _streamLog('raw chunk session=$sessionId data=$chunk');
        buffer.write(chunk);
        yield* _drainSseBuffer(buffer, flush: false);
      }
      yield* _drainSseBuffer(buffer, flush: true);
    } on DioException catch (error) {
      developer.log(
        'AI stream Dio error: type=${error.type}, '
        'status=${error.response?.statusCode}, message=${error.message}',
        name: _streamLogName,
        error: error,
        stackTrace: error.stackTrace,
      );
      throw ApiException(_errorFromDioException(error));
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'AI stream parse error: ${error.message}',
        name: _streamLogName,
        error: error,
        stackTrace: stackTrace,
      );
      throw const ApiException(
        ApiError(code: 'AI_STREAM_PARSE_FAILED', message: 'AI 流式数据解析失败，请重试'),
      );
    } catch (error, stackTrace) {
      developer.log(
        'AI stream read error: $error',
        name: _streamLogName,
        error: error,
        stackTrace: stackTrace,
      );
      throw const ApiException(
        ApiError(
          code: 'AI_STREAM_READ_FAILED',
          message: '网络连接中断，请检查后端服务或网络后重试',
        ),
      );
    }
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

  /// 从后端响应体中提取标准 `error` 对象；没有错误时返回 null。
  ApiError? _errorFromData(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is Map<String, dynamic>) {
      return ApiError.fromJson(error);
    }
    return null;
  }

  /// 把 Dio 的网络异常映射成稳定的业务错误码和中文提示。
  ///
  /// 流式请求中断时 Controller 会根据这些错误码决定是否自动重试。
  ApiError _errorFromDioException(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final apiError = _errorFromData(data);
      if (apiError != null) {
        return apiError;
      }
    }

    final code = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => 'NETWORK_INTERRUPTED',
      DioExceptionType.cancel => 'REQUEST_CANCELLED',
      DioExceptionType.badCertificate => 'BAD_CERTIFICATE',
      DioExceptionType.badResponse => 'STREAM_BAD_RESPONSE',
    };

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout => '连接后端服务超时，请检查网络后重试',
      DioExceptionType.sendTimeout => '请求发送超时，请检查网络后重试',
      DioExceptionType.receiveTimeout => 'AI 建议响应超时，请稍后重试',
      DioExceptionType.connectionError => '网络连接中断，请检查后端服务或网络后重试',
      DioExceptionType.cancel => 'AI 建议请求已取消',
      DioExceptionType.badCertificate => '网络证书异常，请检查服务配置',
      DioExceptionType.badResponse => 'AI 流式接口响应异常，请稍后重试',
      DioExceptionType.unknown => '网络连接异常，请检查后端服务或网络后重试',
    };

    return ApiError(code: code, message: message);
  }

  /// 从 SSE 文本缓冲区中取出完整事件块，保留未完成块等待下个 chunk。
  ///
  /// [flush] 为 true 时会在流结束时尝试解析缓冲区剩余内容。
  Stream<SplendorAiAdviceStreamEvent> _drainSseBuffer(
    StringBuffer buffer, {
    required bool flush,
  }) async* {
    final text = buffer.toString();
    final normalizedText = text.replaceAll('\r\n', '\n');
    final eventBlocks = normalizedText.split('\n\n');
    final completeBlocks = flush
        ? eventBlocks
        : eventBlocks.take(eventBlocks.length - 1);

    buffer.clear();
    if (!flush && eventBlocks.isNotEmpty) {
      buffer.write(eventBlocks.last);
    }

    for (final block in completeBlocks) {
      if (block.trim().isNotEmpty) {
        _streamLog('sse block=$block');
      }
      final event = _parseSseBlock(block);
      if (event != null) {
        _streamLog(
          'event type=${event.type} text=${event.text} '
          'hasResponse=${event.response != null}',
        );
        yield event;
      }
    }
  }

  /// 解析单个 SSE block 的 `data:` 内容并转换成 AI 建议流事件。
  ///
  /// 空事件和 `[DONE]` 返回 null；后端标准错误会抛出 `ApiException`。
  SplendorAiAdviceStreamEvent? _parseSseBlock(String block) {
    final dataLines = block
        .split('\n')
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trimLeft())
        .join('\n')
        .trim();
    if (dataLines.isEmpty || dataLines == '[DONE]') {
      return null;
    }

    final decoded = jsonDecode(dataLines);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      throw ApiException(ApiError.fromJson(error));
    }
    return SplendorAiAdviceStreamEvent.fromJson(decoded);
  }

  /// 输出 AI 流式接口专用日志，便于排查 chunk 和 SSE 解析问题。
  void _streamLog(String message) {
    debugPrint('[$_streamLogName] $message');
  }
}
