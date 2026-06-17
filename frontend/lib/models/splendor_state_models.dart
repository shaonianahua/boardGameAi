// 璀璨宝石游戏状态模型。
// session、action、legal-action 等接口都会复用这些状态快照。
import 'splendor_base_models.dart';

/// 单个玩家在当前对局状态中的公开信息。
class SplendorPlayerState {
  /// 构造玩家状态，字段对应后端 `state.players[]`。
  const SplendorPlayerState({
    required this.seatIndex,
    required this.name,
    required this.type,
    this.botLevel,
    required this.score,
    required this.tokens,
    required this.bonuses,
    required this.purchasedCards,
    required this.reservedCards,
    required this.nobles,
  });

  /// 从后端玩家状态 JSON 解析。
  factory SplendorPlayerState.fromJson(JsonMap json) {
    return SplendorPlayerState(
      seatIndex: json['seatIndex'] as int,
      name: json['name'] as String,
      type: SplendorPlayerType.fromJson(json['type'] as String?),
      botLevel: json['botLevel'] as String?,
      score: json['score'] as int,
      tokens: SplendorTokenSet.fromJson(json['tokens'] as JsonMap?),
      bonuses: SplendorGemSet.fromJson(json['bonuses'] as JsonMap?),
      purchasedCards: stringList(json['purchasedCards']),
      reservedCards: stringList(json['reservedCards']),
      nobles: stringList(json['nobles']),
    );
  }

  /// 玩家座位下标。
  final int seatIndex;

  /// 玩家显示名称。
  final String name;

  /// 玩家类型，后续 Bot 策略会用到。
  final SplendorPlayerType type;

  /// Bot 难度或等级，真人玩家为空。
  final String? botLevel;

  /// 当前总分，包含发展卡和贵族分。
  final int score;

  /// 玩家当前持有 token。
  final SplendorTokenSet tokens;

  /// 玩家购买发展卡后获得的永久宝石折扣。
  final SplendorGemSet bonuses;

  /// 已购买发展卡 ID 列表。
  final List<String> purchasedCards;

  /// 已预留发展卡 ID 列表。
  final List<String> reservedCards;

  /// 已获得贵族 ID 列表。
  final List<String> nobles;
}

/// 后端要求玩家先处理的挂起行动。
///
/// 当前 V1 实际使用 `discard_tokens`；贵族会在回合收尾由后端自动结算。
class SplendorPendingAction {
  /// 构造“弃 token”挂起行动。
  const SplendorPendingAction.discardTokens({
    required this.playerIndex,
    required this.tokenCount,
    required this.maxTokenCount,
  }) : type = SplendorActionType.discardTokens,
       nobleIds = const [];

  /// 构造“选择贵族”挂起行动，当前仅保留对旧状态结构的兼容解析。
  const SplendorPendingAction.chooseNoble({
    required this.playerIndex,
    required this.nobleIds,
  }) : type = SplendorActionType.chooseNoble,
       tokenCount = null,
       maxTokenCount = null;

  /// 从后端 pendingAction JSON 解析具体挂起行动。
  factory SplendorPendingAction.fromJson(JsonMap? json) {
    if (json == null) {
      throw ArgumentError('pending action json is required');
    }

    final type = SplendorActionType.fromJson(json['type'] as String?);
    if (type == SplendorActionType.chooseNoble) {
      return SplendorPendingAction.chooseNoble(
        playerIndex: json['playerIndex'] as int,
        nobleIds: stringList(json['nobleIds']),
      );
    }

    return SplendorPendingAction.discardTokens(
      playerIndex: json['playerIndex'] as int,
      tokenCount: json['tokenCount'] as int,
      maxTokenCount: json['maxTokenCount'] as int,
    );
  }

  /// 挂起行动类型。
  final SplendorActionType type;

  /// 需要处理该挂起行动的玩家下标。
  final int playerIndex;

  /// 当前 token 总数，仅弃 token 场景有值。
  final int? tokenCount;

  /// 允许持有的 token 上限，仅弃 token 场景有值。
  final int? maxTokenCount;

  /// 可选择的贵族 ID 列表；当前 V1 自动结算贵族时不会使用。
  final List<String> nobleIds;
}

/// 当前璀璨宝石对局的完整状态快照。
class SplendorGameState {
  /// 构造游戏状态，字段对应后端 `SplendorGameState`。
  const SplendorGameState({
    required this.gameType,
    required this.status,
    required this.playerCount,
    required this.currentTurnIndex,
    required this.currentPlayerIndex,
    required this.tokenPool,
    required this.markets,
    required this.decks,
    required this.nobles,
    required this.players,
    required this.finalRound,
    required this.pendingAction,
    required this.winnerPlayerIndex,
  });

  /// 从后端状态 JSON 解析完整对局快照。
  factory SplendorGameState.fromJson(JsonMap json) {
    return SplendorGameState(
      gameType: json['gameType'] as String,
      status: SplendorSessionStatus.fromJson(json['status'] as String?),
      playerCount: json['playerCount'] as int,
      currentTurnIndex: json['currentTurnIndex'] as int,
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      tokenPool: SplendorTokenSet.fromJson(json['tokenPool'] as JsonMap?),
      markets: SplendorCardArea.fromJson(json['markets'] as JsonMap?),
      decks: SplendorCardArea.fromJson(json['decks'] as JsonMap?),
      nobles: stringList(json['nobles']),
      players: objectList(json['players'], SplendorPlayerState.fromJson),
      finalRound: SplendorFinalRound.fromJson(json['finalRound'] as JsonMap?),
      pendingAction: json['pendingAction'] == null
          ? null
          : SplendorPendingAction.fromJson(json['pendingAction'] as JsonMap),
      winnerPlayerIndex: json['winnerPlayerIndex'] as int?,
    );
  }

  /// 游戏类型，当前 V1 预期是璀璨宝石。
  final String gameType;

  /// 当前对局状态。
  final SplendorSessionStatus status;

  /// 玩家数量。
  final int playerCount;

  /// 当前回合序号。
  final int currentTurnIndex;

  /// 当前应该操作的玩家下标。
  final int currentPlayerIndex;

  /// 公共 token 池。
  final SplendorTokenSet tokenPool;

  /// 场上公开市场卡牌 ID，按等级分组。
  final SplendorCardArea markets;

  /// 牌堆剩余卡牌 ID，按等级分组。
  final SplendorCardArea decks;

  /// 场上可获得贵族 ID 列表。
  final List<String> nobles;

  /// 玩家状态列表。
  final List<SplendorPlayerState> players;

  /// 终局轮信息。
  final SplendorFinalRound finalRound;

  /// 当前必须先处理的挂起行动，没有挂起行动时为空。
  final SplendorPendingAction? pendingAction;

  /// 获胜玩家下标，对局未结束时为空。
  final int? winnerPlayerIndex;
}

/// 按等级分组的卡牌 ID 区域。
///
/// 同一结构用于公开市场和牌堆剩余卡牌。
class SplendorCardArea {
  /// 构造三层卡牌区域。
  const SplendorCardArea({
    required this.level1,
    required this.level2,
    required this.level3,
  });

  /// 从后端卡牌区域 JSON 解析，缺失列表按空列表处理。
  factory SplendorCardArea.fromJson(JsonMap? json) {
    return SplendorCardArea(
      level1: stringList(json?['level1']),
      level2: stringList(json?['level2']),
      level3: stringList(json?['level3']),
    );
  }

  /// 一级发展卡 ID 列表。
  final List<String> level1;

  /// 二级发展卡 ID 列表。
  final List<String> level2;

  /// 三级发展卡 ID 列表。
  final List<String> level3;
}

/// 终局轮状态。
class SplendorFinalRound {
  /// 构造终局轮信息。
  const SplendorFinalRound({
    required this.triggered,
    required this.triggeredByPlayerIndex,
    required this.roundEndPlayerIndex,
  });

  /// 从后端 finalRound JSON 解析，缺失时表示尚未触发终局。
  factory SplendorFinalRound.fromJson(JsonMap? json) {
    return SplendorFinalRound(
      triggered: json?['triggered'] as bool? ?? false,
      triggeredByPlayerIndex: json?['triggeredByPlayerIndex'] as int?,
      roundEndPlayerIndex: json?['roundEndPlayerIndex'] as int?,
    );
  }

  /// 是否已触发终局轮。
  final bool triggered;

  /// 触发终局的玩家下标。
  final int? triggeredByPlayerIndex;

  /// 终局轮应结束在谁之后。
  final int? roundEndPlayerIndex;
}
