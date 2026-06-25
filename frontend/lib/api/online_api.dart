import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/api_models.dart';
import '../models/online_room_models.dart';
import '../shared/network/api_client.dart';
import 'api_config.dart';
import 'api_paths.dart';

/// 在线房间接口封装。
///
/// 当前只处理房间大厅 MVP：创建房间、加入房间、查询房间和订阅房间事件。
class OnlineApi {
  /// 可注入 `ApiClient` 方便测试；默认使用 `ApiConfig.defaultBaseUrl`。
  OnlineApi({ApiClient? apiClient, String? baseUrl})
    : _baseUrl = baseUrl ?? ApiConfig.defaultBaseUrl,
      _apiClient =
          apiClient ?? ApiClient(baseUrl: baseUrl ?? ApiConfig.defaultBaseUrl);

  final ApiClient _apiClient;
  final String _baseUrl;
  static const _logName = 'online.api';

  /// 调用 `POST /api/online/rooms` 创建在线房间。
  Future<OnlineRoom> createRoom(CreateOnlineRoomInput input) async {
    final response = await _request(
      () => _apiClient.post<Map<String, dynamic>>(
        ApiPaths.onlineRooms,
        data: input.toJson(),
      ),
    );
    return OnlineRoom.fromJson(_data(response));
  }

  /// 调用 `POST /api/online/rooms/join` 加入在线房间。
  Future<OnlineRoom> joinRoom(JoinOnlineRoomInput input) async {
    final response = await _request(
      () => _apiClient.post<Map<String, dynamic>>(
        ApiPaths.onlineRoomsJoin,
        data: input.toJson(),
      ),
    );
    return OnlineRoom.fromJson(_data(response));
  }

  /// 调用 `GET /api/online/rooms/:roomCode` 查询房间快照。
  Future<OnlineRoom> getRoom(String roomCode) async {
    final response = await _request(
      () => _apiClient.get<Map<String, dynamic>>(ApiPaths.onlineRoom(roomCode)),
    );
    return OnlineRoom.fromJson(_data(response));
  }

  /// 调用 `POST /api/online/rooms/leave` 删除当前设备座位并通知房间内其他玩家。
  ///
  /// 后端会按 `clientId` 删除座位；若离开者是房主则把房主转移给剩余最小座位号，
  /// 房间清空时置为 closed。返回最新房间快照（座位为空时为 closed 快照）。
  Future<OnlineRoom> leaveRoom(LeaveOnlineRoomInput input) async {
    final response = await _request(
      () => _apiClient.post<Map<String, dynamic>>(
        ApiPaths.onlineRoomsLeave,
        data: input.toJson(),
      ),
    );
    return OnlineRoom.fromJson(_data(response));
  }

  /// 调用 `POST /api/online/rooms/:roomCode/start` 开始游戏。
  ///
  /// 仅房主可调用。后端会把房间座位映射成对局玩家，创建 game_session，
  /// 房间状态置为 `playing` 并写入 `sessionId`，然后广播 `game_started` 事件。
  /// 若首位玩家是 Bot/AI，后端会自动驱动其回合直到轮到真人。
  Future<Map<String, dynamic>> startGame(String roomCode, String clientId) async {
    final response = await _request(
      () => _apiClient.post<Map<String, dynamic>>(
        ApiPaths.onlineRoomStart(roomCode),
        data: {'clientId': clientId},
      ),
    );
    return _data(response);
  }

  /// 连接 `WebSocket /api/online/rooms/:roomCode/events` 并持续返回房间事件。
  ///
  /// 后端连接成功后会先返回 `room_snapshot`，房间座位变化时返回 `room_updated`。
  /// 传入 `clientId` 时会作为查询参数带上，后端在 socket 断开时据此删除对应座位。
  Stream<OnlineRoomEvent> watchRoomEvents(
    String roomCode, {
    String? clientId,
  }) async* {
    final socketUrl = _webSocketUrl(
      ApiPaths.onlineRoomEvents(roomCode),
      queryParameters: clientId != null && clientId.isNotEmpty
          ? {'clientId': clientId}
          : null,
    );
    WebSocket? socket;

    try {
      developer.log('connect websocket $socketUrl', name: _logName);
      socket = await WebSocket.connect(socketUrl);
      await for (final message in socket) {
        if (message is! String) {
          continue;
        }
        developer.log('websocket message $message', name: _logName);
        final decoded = jsonDecode(message);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          throw ApiException(ApiError.fromJson(error));
        }
        if (decoded['room'] is Map<String, dynamic>) {
          yield OnlineRoomEvent.fromJson(decoded);
        }
      }
    } on ApiException {
      rethrow;
    } catch (error, stackTrace) {
      developer.log(
        'websocket failed: $error',
        name: _logName,
        error: error,
        stackTrace: stackTrace,
      );
      throw const ApiException(
        ApiError(code: 'ONLINE_ROOM_SOCKET_FAILED', message: '房间实时连接失败，请稍后重试'),
      );
    } finally {
      await socket?.close();
    }
  }

  /// 包装 Dio 请求，把后端 `{ error }` 响应转成 `ApiException`。
  Future<Response<Map<String, dynamic>>> _request(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final data = error.response?.data;
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

  /// 提取后端响应体，并把标准错误体转成 `ApiException`。
  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) {
      throw const ApiException(
        ApiError(code: 'EMPTY_RESPONSE', message: 'empty response'),
      );
    }

    final apiError = _errorFromData(data);
    if (apiError != null) {
      throw ApiException(apiError);
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

  /// 根据 HTTP baseUrl 和 path 生成 WebSocket URL。
  ///
  /// `queryParameters` 用于在事件连接上携带 `clientId` 等参数。
  String _webSocketUrl(String path, {Map<String, String>? queryParameters}) {
    final baseUri = Uri.parse(_baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUri
        .replace(
          scheme: scheme,
          path: normalizedPath,
          queryParameters: queryParameters,
        )
        .toString();
  }
}
