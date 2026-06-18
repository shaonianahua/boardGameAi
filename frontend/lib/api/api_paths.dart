/// 全项目 API 路径登记表。
///
/// API 调用层从这里取 path，避免页面或 service 中散落接口字符串。
class ApiPaths {
  const ApiPaths._();

  /// 后端健康检查接口。
  static const health = '/health';

  /// 璀璨宝石固定卡牌和贵族图鉴接口。
  static const splendorCatalog = '/api/splendor/catalog';

  /// 璀璨宝石对局集合接口，用于创建对局。
  static const splendorSessions = '/api/splendor/sessions';

  /// 单个璀璨宝石对局详情接口。
  static String splendorSession(String sessionId) {
    return '$splendorSessions/$sessionId';
  }

  /// 单个对局当前可执行行动接口。
  static String splendorLegalActions(String sessionId) {
    return '${splendorSession(sessionId)}/legal-actions';
  }

  /// 单个对局行动提交和行动历史接口。
  static String splendorActions(String sessionId) {
    return '${splendorSession(sessionId)}/actions';
  }

  /// V2 本地 Bot 自动行动接口，后端会为当前 Bot 玩家选择并执行一个合法行动。
  static String splendorBotAct(String sessionId) {
    return '${splendorSession(sessionId)}/bot/act';
  }
}
