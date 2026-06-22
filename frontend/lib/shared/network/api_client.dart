import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 全项目共用的 Dio 网络客户端。
///
/// 统一配置超时、JSON 编解码、Authorization header 和请求日志，业务 API 不直接创建 Dio。
class ApiClient {
  static const authorizationHeader = 'Authorization';
  static const _logName = 'api.client';
  static const _maxLogLength = 2400;

  ApiClient({
    Dio? dio,
    String baseUrl = '',
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 190),
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: connectTimeout,
               receiveTimeout: receiveTimeout,
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
             ),
           ) {
    _dio.interceptors.add(_createLogInterceptor());
  }

  final Dio _dio;

  Dio get dio => _dio;

  /// 设置或清除 Bearer Token。
  ///
  /// 日志输出时会自动脱敏 Authorization，避免后续接入用户登录后泄漏 token。
  void setBearerToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove(authorizationHeader);
      return;
    }

    _dio.options.headers[authorizationHeader] = 'Bearer $token';
  }

  /// 发送 GET 请求，queryParameters 会在统一日志里打印。
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// 发送 POST 请求，data 和 queryParameters 会在统一日志里打印。
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// 发送 PUT 请求，data 和 queryParameters 会在统一日志里打印。
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// 发送 DELETE 请求，data 和 queryParameters 会在统一日志里打印。
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  InterceptorsWrapper _createLogInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        _writeLog(_formatRequestLog(options));
        handler.next(options);
      },
      onResponse: (response, handler) {
        _writeLog(_formatResponseLog(response));
        handler.next(response);
      },
      onError: (error, handler) {
        _writeLog(_formatErrorLog(error));
        handler.next(error);
      },
    );
  }

  void _writeLog(String message) {
    debugPrint('[$_logName] $message');
  }

  String _formatRequestLog(RequestOptions options) {
    return _clipLog(
      'request ${options.method} ${options.uri}\n'
      'path=${options.path}\n'
      'query=${_stringify(options.queryParameters)}\n'
      'headers=${_stringify(_mergedHeaders(options))}\n'
      'data=${_stringify(options.data)}',
    );
  }

  String _formatResponseLog(Response<dynamic> response) {
    return _clipLog(
      'response ${response.requestOptions.method} ${response.requestOptions.uri}\n'
      'status=${response.statusCode}\n'
      'headers=${_stringify(response.headers.map)}\n'
      'data=${_stringify(response.data)}',
    );
  }

  String _formatErrorLog(DioException error) {
    final response = error.response;
    return _clipLog(
      'error ${error.requestOptions.method} ${error.requestOptions.uri}\n'
      'type=${error.type}\n'
      'message=${error.message}\n'
      'status=${response?.statusCode}\n'
      'requestHeaders=${_stringify(_mergedHeaders(error.requestOptions))}\n'
      'requestData=${_stringify(error.requestOptions.data)}\n'
      'responseData=${_stringify(response?.data)}',
    );
  }

  Map<String, dynamic> _mergedHeaders(RequestOptions options) {
    return _maskHeaders({..._dio.options.headers, ...options.headers});
  }

  Map<String, dynamic> _maskHeaders(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      final normalizedKey = key.toLowerCase();
      if (normalizedKey == authorizationHeader.toLowerCase()) {
        return MapEntry(key, _maskSecret(value));
      }
      return MapEntry(key, value);
    });
  }

  String _maskSecret(Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) {
      return '';
    }
    if (text.length <= 12) {
      return '***';
    }
    return '${text.substring(0, 8)}...${text.substring(text.length - 4)}';
  }

  String _stringify(Object? value) {
    if (value == null) {
      return 'null';
    }
    return value.toString();
  }

  String _clipLog(String text) {
    if (text.length <= _maxLogLength) {
      return text;
    }
    return '${text.substring(0, _maxLogLength)}...<truncated ${text.length - _maxLogLength} chars>';
  }
}
