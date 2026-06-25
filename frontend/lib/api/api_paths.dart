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

  /// V2 AI 玩家自动行动接口，后端调用模型选行动，失败时回退本地 Bot。
  static String splendorAiAct(String sessionId) {
    return '${splendorSession(sessionId)}/ai/act';
  }

  /// V2 AI 建议接口，第一版由后端本地启发式返回结构化建议。
  static String splendorAiDecision(String sessionId) {
    return '${splendorSession(sessionId)}/ai/decide';
  }

  /// V2 AI 流式建议接口，后端以 SSE 事件逐段返回分析内容和最终结构化建议。
  static String splendorAiStream(String sessionId) {
    return '${splendorSession(sessionId)}/ai/stream';
  }

  /// 在线房间集合接口，用于创建房间。
  static const onlineRooms = '/api/online/rooms';

  /// 在线房间加入接口，用于通过房间码进入等待大厅。
  static const onlineRoomsJoin = '/api/online/rooms/join';

  /// 在线房间离开接口，用于删除当前设备座位并通知房间内其他玩家。
  static const onlineRoomsLeave = '/api/online/rooms/leave';

  /// 在线房间开始游戏接口，仅房主可调用；座位映射成玩家创建对局。
  static String onlineRoomStart(String roomCode) =>
      '$onlineRooms/$roomCode/start';

  /// 单个在线房间快照接口。
  static String onlineRoom(String roomCode) {
    return '$onlineRooms/$roomCode';
  }

  /// 单个在线房间 WebSocket 事件路径。
  static String onlineRoomEvents(String roomCode) {
    return '${onlineRoom(roomCode)}/events';
  }
}
