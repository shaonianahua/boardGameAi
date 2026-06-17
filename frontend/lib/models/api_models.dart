/// 后端统一错误响应结构。
class ApiError {
  /// 构造一个后端错误描述。
  const ApiError({required this.code, required this.message});

  /// 从后端 `error` 对象解析错误信息。
  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      code: json['code'] as String? ?? 'UNKNOWN_ERROR',
      message: json['message'] as String? ?? 'unknown error',
    );
  }

  /// 错误码，供调用方分支处理。
  final String code;

  /// 面向用户或日志的错误说明。
  final String message;
}

/// API 层统一抛出的异常类型。
class ApiException implements Exception {
  /// 使用后端错误信息构造异常。
  const ApiException(this.error);

  /// 已解析好的后端错误对象。
  final ApiError error;

  @override
  String toString() => '${error.code}: ${error.message}';
}
