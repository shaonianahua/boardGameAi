// 璀璨宝石行动请求和响应模型。
// 用于合法行动、提交行动、行动历史接口。
import 'splendor_base_models.dart';
import 'splendor_session_models.dart';
import 'splendor_state_models.dart';

/// 玩家一次可提交或后端返回的璀璨宝石行动。
///
/// `payload` 保留后端 action 原始结构，方便不同 action 类型携带不同字段。
class SplendorAction {
  /// 内部构造方法，统一保存行动类型和原始 payload。
  const SplendorAction._(this.type, this.payload);

  /// 从后端 action JSON 解析行动。
  factory SplendorAction.fromJson(JsonMap json) {
    return SplendorAction._(
      SplendorActionType.fromJson(json['type'] as String?),
      Map<String, dynamic>.from(json),
    );
  }

  /// 构造“拿取 token”行动。
  factory SplendorAction.takeTokens(SplendorTokenSet tokens) {
    return SplendorAction._(SplendorActionType.takeTokens, {
      'type': SplendorActionType.takeTokens.value,
      'tokens': tokens.toJson(includeZero: false),
    });
  }

  /// 构造“预留卡牌”行动。
  ///
  /// `source` 用于区分公开市场或牌堆；从牌堆预留时 `cardId` 可以为空。
  factory SplendorAction.reserveCard({
    required String source,
    required int level,
    String? cardId,
  }) {
    return SplendorAction._(SplendorActionType.reserveCard, {
      'type': SplendorActionType.reserveCard.value,
      'source': source,
      'level': level,
      'cardId': ?cardId,
    });
  }

  /// 构造“购买卡牌”行动。
  ///
  /// `payment` 可由前端显式传入，也可交给后端按规则计算，取决于后续 UI 设计。
  factory SplendorAction.buyCard({
    required String source,
    required String cardId,
    SplendorTokenSet? payment,
  }) {
    return SplendorAction._(SplendorActionType.buyCard, {
      'type': SplendorActionType.buyCard.value,
      'source': source,
      'cardId': cardId,
      'payment': ?payment?.toJson(includeZero: false),
    });
  }

  /// 构造“弃 token”行动，用于处理超过 10 个 token 的挂起状态。
  factory SplendorAction.discardTokens(SplendorTokenSet tokens) {
    return SplendorAction._(SplendorActionType.discardTokens, {
      'type': SplendorActionType.discardTokens.value,
      'tokens': tokens.toJson(includeZero: false),
    });
  }

  /// 构造“选择贵族”行动。
  ///
  /// 当前 V1 规则已改为回合收尾自动获得贵族；这里仅保留对旧 action 结构的兼容解析入口。
  factory SplendorAction.chooseNoble(String nobleId) {
    return SplendorAction._(SplendorActionType.chooseNoble, {
      'type': SplendorActionType.chooseNoble.value,
      'nobleId': nobleId,
    });
  }

  /// 行动类型。
  final SplendorActionType type;

  /// 行动原始字段，提交接口时直接作为 action JSON。
  final JsonMap payload;

  /// 转成提交行动接口需要的 action JSON。
  JsonMap toJson() => payload;
}

/// `POST /api/splendor/sessions/:sessionId/actions` 的请求体。
class SplendorSubmitActionInput {
  /// 构造提交行动请求体。
  const SplendorSubmitActionInput({
    required this.playerIndex,
    required this.action,
    this.actorType,
  });

  /// 执行动作的玩家下标。
  final int playerIndex;

  /// 具体行动内容。
  final SplendorAction action;

  /// 行动发起方类型，后续区分 human/bot/ai 时使用。
  final String? actorType;

  /// 转成提交行动接口请求 JSON。
  JsonMap toJson() {
    return {
      'playerIndex': playerIndex,
      'actorType': ?actorType,
      'action': action.toJson(),
    };
  }
}

/// 后端返回的一条当前合法行动。
class SplendorLegalAction {
  /// 构造合法行动展示项。
  const SplendorLegalAction({required this.action, required this.label});

  /// 从 legal-actions 响应中的单项 JSON 解析。
  factory SplendorLegalAction.fromJson(JsonMap json) {
    return SplendorLegalAction(
      action: SplendorAction.fromJson(json['action'] as JsonMap),
      label: json['label'] as String,
    );
  }

  /// 可提交的行动内容。
  final SplendorAction action;

  /// 后端给出的行动说明，供 UI 展示或调试使用。
  final String label;
}

/// `GET /api/splendor/sessions/:sessionId/legal-actions` 的响应体。
class SplendorLegalActionsResponse {
  /// 构造合法行动响应。
  const SplendorLegalActionsResponse({
    required this.playerIndex,
    required this.pendingAction,
    required this.actions,
    required this.disabledReasons,
  });

  /// 从 legal-actions 响应 JSON 解析。
  factory SplendorLegalActionsResponse.fromJson(JsonMap json) {
    return SplendorLegalActionsResponse(
      playerIndex: json['playerIndex'] as int,
      pendingAction: json['pendingAction'] == null
          ? null
          : SplendorPendingAction.fromJson(json['pendingAction'] as JsonMap),
      actions: objectList(json['actions'], SplendorLegalAction.fromJson),
      disabledReasons: stringList(json['disabledReasons']),
    );
  }

  /// 当前应该行动或处理挂起行动的玩家下标。
  final int playerIndex;

  /// 当前必须优先处理的挂起行动，没有时为空。
  final SplendorPendingAction? pendingAction;

  /// 后端判定当前可执行的行动列表。
  final List<SplendorLegalAction> actions;

  /// 无法行动或行动受限的原因列表，供 UI 禁用提示使用。
  final List<String> disabledReasons;
}

/// 后端保存的一条对局操作记录。
class SplendorActionRecord {
  /// 构造行动历史记录。
  const SplendorActionRecord({
    required this.id,
    required this.sessionId,
    required this.turnIndex,
    required this.playerIndex,
    required this.actorType,
    required this.actionType,
    required this.action,
    required this.stateBefore,
    required this.stateAfter,
    required this.createdAt,
  });

  /// 从 action-history JSON 解析行动记录。
  factory SplendorActionRecord.fromJson(JsonMap json) {
    return SplendorActionRecord(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      turnIndex: json['turnIndex'] as int,
      playerIndex: json['playerIndex'] as int,
      actorType: json['actorType'] as String,
      actionType: json['actionType'] as String,
      action: SplendorAction.fromJson(json['action'] as JsonMap),
      stateBefore: SplendorGameState.fromJson(json['stateBefore'] as JsonMap),
      stateAfter: SplendorGameState.fromJson(json['stateAfter'] as JsonMap),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 行动记录 ID。
  final String id;

  /// 所属对局 ID。
  final String sessionId;

  /// 行动发生时的回合序号。
  final int turnIndex;

  /// 执行动作的玩家下标。
  final int playerIndex;

  /// 行动发起方类型，例如 human/bot。
  final String actorType;

  /// 后端记录的行动类型字符串。
  final String actionType;

  /// 行动内容。
  final SplendorAction action;

  /// 行动执行前的状态快照。
  final SplendorGameState stateBefore;

  /// 行动执行后的状态快照。
  final SplendorGameState stateAfter;

  /// 行动记录创建时间。
  final DateTime createdAt;
}

/// 提交行动接口响应。
class SplendorSubmitActionResponse {
  /// 构造提交行动响应，包含更新后的 session、行动记录和状态。
  const SplendorSubmitActionResponse({
    required this.session,
    required this.actionRecord,
    required this.state,
  });

  /// 从 `POST /api/splendor/sessions/:sessionId/actions` 响应 JSON 解析。
  factory SplendorSubmitActionResponse.fromJson(JsonMap json) {
    return SplendorSubmitActionResponse(
      session: SplendorSession.fromJson(json['session'] as JsonMap),
      actionRecord: SplendorActionRecord.fromJson(
        json['actionRecord'] as JsonMap,
      ),
      state: SplendorGameState.fromJson(json['state'] as JsonMap),
    );
  }

  /// 更新后的对局元信息。
  final SplendorSession session;

  /// 本次提交生成的行动记录。
  final SplendorActionRecord actionRecord;

  /// 行动执行后的游戏状态快照。
  final SplendorGameState state;
}

/// 后端本地 Bot 自动行动接口返回的决策信息。
class SplendorBotDecision {
  /// 构造 Bot 决策信息，记录本地启发式选择的行动和简短理由。
  const SplendorBotDecision({
    required this.score,
    required this.reason,
    required this.selectedAction,
  });

  /// 从 `POST /bot/act` 响应中的 decision JSON 解析。
  factory SplendorBotDecision.fromJson(JsonMap json) {
    return SplendorBotDecision(
      score: (json['score'] as num).toDouble(),
      reason: json['reason'] as String? ?? 'Bot 已选择一个合法行动',
      selectedAction: SplendorAction.fromJson(
        json['selectedAction'] as JsonMap,
      ),
    );
  }

  /// 本地启发式评分，用于调试或后续展示 Bot 思路。
  final double score;

  /// Bot 选择该行动的简短原因。
  final String reason;

  /// Bot 最终提交给后端规则引擎的行动。
  final SplendorAction selectedAction;
}

/// Bot 自动行动接口响应，结构与提交行动响应一致，并额外携带决策说明。
class SplendorBotActionResponse {
  /// 构造 Bot 自动行动响应。
  const SplendorBotActionResponse({
    required this.session,
    required this.actionRecord,
    required this.state,
    required this.decision,
  });

  /// 从 `POST /api/splendor/sessions/:sessionId/bot/act` 响应 JSON 解析。
  factory SplendorBotActionResponse.fromJson(JsonMap json) {
    return SplendorBotActionResponse(
      session: SplendorSession.fromJson(json['session'] as JsonMap),
      actionRecord: SplendorActionRecord.fromJson(
        json['actionRecord'] as JsonMap,
      ),
      state: SplendorGameState.fromJson(json['state'] as JsonMap),
      decision: SplendorBotDecision.fromJson(json['decision'] as JsonMap),
    );
  }

  /// 更新后的对局元信息。
  final SplendorSession session;

  /// Bot 本次行动生成的历史记录。
  final SplendorActionRecord actionRecord;

  /// 行动执行后的完整游戏状态。
  final SplendorGameState state;

  /// 本地 Bot 启发式决策说明。
  final SplendorBotDecision decision;
}

/// AI 建议接口返回的结构化决策内容。
///
/// 第一版由后端本地启发式生成，后续接入大模型时继续复用这组字段展示策略面板。
class SplendorAiAdviceDecision {
  /// 构造 AI 建议决策内容。
  const SplendorAiAdviceDecision({
    required this.actionId,
    required this.confidence,
    required this.summary,
    required this.reasoning,
    required this.alternatives,
    required this.threats,
    required this.risks,
  });

  /// 从 `POST /api/splendor/sessions/:sessionId/ai/decide` 的 decision 字段解析。
  factory SplendorAiAdviceDecision.fromJson(JsonMap json) {
    return SplendorAiAdviceDecision(
      actionId: json['actionId'] as String?,
      confidence: (json['confidence'] as num? ?? 0).toDouble(),
      summary: json['summary'] as String? ?? '暂无明确建议',
      reasoning: stringList(json['reasoning']),
      alternatives: stringList(json['alternatives']),
      threats: stringList(json['threats']),
      risks: stringList(json['risks']),
    );
  }

  /// 推荐行动的稳定 ID；为空表示当前没有可推荐行动。
  final String? actionId;

  /// 建议置信度，取值通常在 0-1 之间。
  final double confidence;

  /// 面板顶部展示的结论。
  final String summary;

  /// 推荐该行动的理由列表。
  final List<String> reasoning;

  /// 备选行动说明列表。
  final List<String> alternatives;

  /// 对手威胁或需要关注的局面信息。
  final List<String> threats;

  /// 当前建议可能存在的风险。
  final List<String> risks;
}

/// AI 建议接口响应。
///
/// `selectedAction` 只用于展示推荐行动，不会在前端自动执行。
class SplendorAiAdviceResponse {
  /// 构造 AI 建议响应。
  const SplendorAiAdviceResponse({
    required this.decision,
    required this.selectedAction,
  });

  /// 从 AI 建议接口 JSON 解析。
  factory SplendorAiAdviceResponse.fromJson(JsonMap json) {
    return SplendorAiAdviceResponse(
      decision: SplendorAiAdviceDecision.fromJson(json['decision'] as JsonMap),
      selectedAction: json['selectedAction'] == null
          ? null
          : SplendorLegalAction.fromJson(json['selectedAction'] as JsonMap),
    );
  }

  /// 结构化建议内容。
  final SplendorAiAdviceDecision decision;

  /// 后端推荐的合法行动；为空表示当前没有可执行建议。
  final SplendorLegalAction? selectedAction;
}

/// AI 建议流式接口的单个事件。
///
/// `progress` / `delta` 用于渐进展示文字，`result` 携带最终结构化建议。
class SplendorAiAdviceStreamEvent {
  /// 构造 AI 建议流式事件。
  const SplendorAiAdviceStreamEvent({
    required this.type,
    required this.text,
    required this.response,
  });

  /// 从 `POST /api/splendor/sessions/:sessionId/ai/stream` 的 SSE data 解析。
  factory SplendorAiAdviceStreamEvent.fromJson(JsonMap json) {
    return SplendorAiAdviceStreamEvent(
      type: json['type'] as String? ?? 'delta',
      text: json['text'] as String? ?? '',
      response: json['response'] == null
          ? null
          : SplendorAiAdviceResponse.fromJson(json['response'] as JsonMap),
    );
  }

  /// 事件类型，例如 progress、delta、result、done。
  final String type;

  /// 可直接展示在流式面板中的文字片段。
  final String text;

  /// 最终结构化建议；只有 result 事件会携带。
  final SplendorAiAdviceResponse? response;
}

/// 行动历史接口响应。
class SplendorActionsResponse {
  /// 构造行动历史响应。
  const SplendorActionsResponse({required this.actions});

  /// 从 `GET /api/splendor/sessions/:sessionId/actions` 响应 JSON 解析。
  factory SplendorActionsResponse.fromJson(JsonMap json) {
    return SplendorActionsResponse(
      actions: objectList(json['actions'], SplendorActionRecord.fromJson),
    );
  }

  /// 当前对局的历史行动记录列表。
  final List<SplendorActionRecord> actions;
}
