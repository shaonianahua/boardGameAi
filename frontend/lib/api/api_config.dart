/// App API 基础配置。
///
/// 默认地址用于本地后端联调，正式运行或真机调试时可以用
/// `--dart-define=API_BASE_URL=...` 覆盖。
class ApiConfig {
  const ApiConfig._();

  /// 后端服务基础地址，供 `ApiClient` 初始化时使用。
  static const defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.110.137:3000',
  );
}
