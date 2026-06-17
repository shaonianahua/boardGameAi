// 璀璨宝石对局请求和响应模型。
// 用于创建对局、获取对局详情等 session 接口。
import 'splendor_base_models.dart';
import 'splendor_state_models.dart';

/// 后端保存的璀璨宝石对局元信息。
class SplendorSession {
  /// 构造对局元信息，字段对应后端 session JSON。
  const SplendorSession({
    required this.id,
    required this.gameType,
    required this.title,
    required this.status,
    required this.playerCount,
    required this.currentTurnIndex,
    required this.currentPlayerIndex,
    required this.winnerPlayerIndex,
    required this.createdAt,
    required this.updatedAt,
    required this.finishedAt,
  });

  /// 从 session JSON 解析对局元信息。
  factory SplendorSession.fromJson(JsonMap json) {
    return SplendorSession(
      id: json['id'] as String,
      gameType: json['gameType'] as String,
      title: json['title'] as String?,
      status: SplendorSessionStatus.fromJson(json['status'] as String?),
      playerCount: json['playerCount'] as int,
      currentTurnIndex: json['currentTurnIndex'] as int,
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      winnerPlayerIndex: json['winnerPlayerIndex'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.parse(json['finishedAt'] as String),
    );
  }

  /// 对局 ID，用于后续获取状态、提交行动和查看历史。
  final String id;

  /// 游戏类型，当前 V1 预期是璀璨宝石。
  final String gameType;

  /// 对局标题，用户未填写时可能为空。
  final String? title;

  /// 当前对局状态。
  final SplendorSessionStatus status;

  /// 本局玩家数量。
  final int playerCount;

  /// 当前回合序号。
  final int currentTurnIndex;

  /// 当前应该操作的玩家座位下标。
  final int currentPlayerIndex;

  /// 获胜玩家座位下标，对局未结束时为空。
  final int? winnerPlayerIndex;

  /// 对局创建时间。
  final DateTime createdAt;

  /// 对局最后更新时间。
  final DateTime updatedAt;

  /// 对局结束时间，对局未结束时为空。
  final DateTime? finishedAt;
}

/// 对局中的一个座位玩家。
class SplendorSeatPlayer {
  /// 构造座位玩家信息，字段对应后端 player JSON。
  const SplendorSeatPlayer({
    required this.id,
    required this.sessionId,
    required this.seatIndex,
    required this.name,
    required this.playerType,
    this.botLevel,
    required this.createdAt,
  });

  /// 从后端 player JSON 解析座位玩家。
  factory SplendorSeatPlayer.fromJson(JsonMap json) {
    return SplendorSeatPlayer(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      seatIndex: json['seatIndex'] as int,
      name: json['name'] as String,
      playerType: SplendorPlayerType.fromJson(json['playerType'] as String?),
      botLevel: json['botLevel'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 玩家记录 ID。
  final String id;

  /// 所属对局 ID。
  final String sessionId;

  /// 座位下标，和 `SplendorGameState.players` 的顺序保持一致。
  final int seatIndex;

  /// 玩家显示名称。
  final String name;

  /// 玩家类型，V1 主要使用真人玩家，后续可接 Bot。
  final SplendorPlayerType playerType;

  /// Bot 难度或等级，真人玩家为空。
  final String? botLevel;

  /// 玩家加入对局记录的创建时间。
  final DateTime createdAt;
}

/// 创建或获取对局接口的完整响应。
class SplendorSessionResponse {
  /// 构造 session 响应，包含元信息、座位玩家和状态快照。
  const SplendorSessionResponse({
    required this.session,
    required this.players,
    required this.state,
  });

  /// 从 `POST/GET /api/splendor/sessions...` 响应 JSON 解析。
  factory SplendorSessionResponse.fromJson(JsonMap json) {
    return SplendorSessionResponse(
      session: SplendorSession.fromJson(json['session'] as JsonMap),
      players: objectList(json['players'], SplendorSeatPlayer.fromJson),
      state: SplendorGameState.fromJson(json['state'] as JsonMap),
    );
  }

  /// 对局元信息。
  final SplendorSession session;

  /// 对局座位玩家列表。
  final List<SplendorSeatPlayer> players;

  /// 当前游戏状态快照。
  final SplendorGameState state;
}

/// 创建对局时提交的单个玩家信息。
class SplendorCreatePlayerInput {
  /// 构造创建对局的玩家入参。
  const SplendorCreatePlayerInput({
    required this.name,
    this.type = SplendorPlayerType.human,
    this.botLevel,
  });

  /// 玩家显示名称。
  final String name;

  /// 玩家类型，默认真人玩家。
  final SplendorPlayerType type;

  /// Bot 难度或等级，真人玩家不传。
  final String? botLevel;

  /// 转成 `POST /api/splendor/sessions` 需要的玩家 JSON。
  JsonMap toJson() {
    return {'name': name, 'type': type.toJson(), 'botLevel': ?botLevel};
  }
}

/// 创建璀璨宝石对局的请求体。
class SplendorCreateSessionInput {
  /// 构造创建对局入参。
  const SplendorCreateSessionInput({
    required this.playerCount,
    this.title,
    required this.players,
  });

  /// 本局玩家数量。
  final int playerCount;

  /// 对局标题，未填写时可为空。
  final String? title;

  /// 创建对局时的玩家列表。
  final List<SplendorCreatePlayerInput> players;

  /// 转成 `POST /api/splendor/sessions` 需要的请求 JSON。
  JsonMap toJson() {
    return {
      'playerCount': playerCount,
      'title': ?title,
      'players': players.map((player) => player.toJson()).toList(),
    };
  }
}
