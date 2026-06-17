import 'package:dio/dio.dart';

class ApiClient {
  static const authorizationHeader = 'Authorization';

  ApiClient({
    Dio? dio,
    String baseUrl = '',
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 15),
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
           );

  final Dio _dio;

  Dio get dio => _dio;

  void setBearerToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove(authorizationHeader);
      return;
    }

    _dio.options.headers[authorizationHeader] = 'Bearer $token';
  }

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
}
