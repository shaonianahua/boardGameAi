import { cardById } from './catalog.js';
import { scoreSplendorLegalAction } from './bot-advisor.js';
import type {
  SplendorAction,
  SplendorGameState,
  SplendorLegalAction,
  SplendorLegalActionsResult,
  SplendorPlayerState,
} from './types.js';

export interface SplendorAdviceDecision {
  actionId: string | null;
  confidence: number;
  summary: string;
  reasoning: string[];
  alternatives: string[];
  threats: string[];
  risks: string[];
}

export interface SplendorAdviceResponse {
  decision: SplendorAdviceDecision;
  selectedAction: SplendorLegalAction | null;
}

interface ScoredLegalAction {
  actionId: string;
  legalAction: SplendorLegalAction;
  score: number;
  reason: string;
}

function actionStableKey(action: SplendorAction): string {
  if (action.type === 'take_tokens') {
    return `take:${Object.entries(action.tokens)
      .filter(([, amount]) => (amount ?? 0) > 0)
      .map(([color, amount]) => `${color}${amount}`)
      .join('-')}`;
  }
  if (action.type === 'buy_card') {
    return `buy:${action.source}:${action.cardId}`;
  }
  if (action.type === 'reserve_card') {
    return `reserve:${action.source}:${action.level}:${action.cardId ?? 'deck'}`;
  }
  if (action.type === 'discard_tokens') {
    return `discard:${Object.entries(action.tokens)
      .filter(([, amount]) => (amount ?? 0) > 0)
      .map(([color, amount]) => `${color}${amount}`)
      .join('-')}`;
  }
  if (action.type === 'choose_noble') {
    return `noble:${action.nobleId}`;
  }
  return `action:${action.type}`;
}

function actionSummary(action: SplendorAction): string {
  if (action.type === 'take_tokens') {
    const tokens = Object.entries(action.tokens)
      .filter(([, amount]) => (amount ?? 0) > 0)
      .map(([color, amount]) => `${color} x${amount}`)
      .join(', ');
    return `拿取 ${tokens}`;
  }
  if (action.type === 'buy_card') {
    const card = cardById.get(action.cardId);
    if (!card) return `购买 ${action.cardId}`;
    return `购买 ${card.bonusColor} 色 ${card.prestige} 分发展卡`;
  }
  if (action.type === 'reserve_card') {
    if (action.source === 'deck') {
      return `从 ${action.level} 级牌堆盲抽预留`;
    }
    const card = action.cardId ? cardById.get(action.cardId) : null;
    if (!card) return `预留 ${action.cardId ?? '公开卡'}`;
    return `预留 ${card.bonusColor} 色 ${card.prestige} 分发展卡`;
  }
  if (action.type === 'discard_tokens') {
    return '弃掉多余宝石';
  }
  return '处理当前待完成行动';
}

function threatLines(state: SplendorGameState, player: SplendorPlayerState): string[] {
  const opponents = state.players.filter((item) => item.seatIndex !== player.seatIndex);
  if (opponents.length === 0) {
    return ['当前没有其他玩家威胁。'];
  }

  return opponents
    .slice(0, 3)
    .map((opponent) => `${opponent.name} 当前 ${opponent.score} 分，预留 ${opponent.reservedCards.length} 张。`);
}

/// 使用本地启发式生成 AI 建议接口的第一版结构化输出。
///
/// 这里不调用大模型，也不执行行动；它只把当前合法行动评分后转成建议面板可展示的数据。
export function createSplendorAdvice(
  state: SplendorGameState,
  legalActions: SplendorLegalActionsResult,
): SplendorAdviceResponse {
  const player = state.players[legalActions.playerIndex];
  if (!player) {
    throw new Error('advice player not found');
  }
  if (legalActions.actions.length === 0) {
    return {
      selectedAction: null,
      decision: {
        actionId: null,
        confidence: 0,
        summary: legalActions.disabledReasons[0] ?? '当前没有可推荐行动。',
        reasoning: ['后端规则引擎没有返回可执行行动。'],
        alternatives: [],
        threats: threatLines(state, player),
        risks: ['需要先确认当前对局是否仍在进行，或是否存在必须处理的挂起行动。'],
      },
    };
  }

  const scoredActions = legalActions.actions
    .map<ScoredLegalAction>((legalAction) => {
      const scored = scoreSplendorLegalAction(state, player, legalAction);
      return {
        actionId: actionStableKey(legalAction.action),
        legalAction,
        score: scored.score,
        reason: scored.reason,
      };
    })
    .sort((left, right) => right.score - left.score);

  const best = scoredActions[0];
  const second = scoredActions[1];
  const confidenceGap = second == null ? 0.82 : Math.min(0.9, Math.max(0.52, (best.score - second.score) / 80 + 0.58));

  return {
    selectedAction: best.legalAction,
    decision: {
      actionId: best.actionId,
      confidence: Number(confidenceGap.toFixed(2)),
      summary: `建议${actionSummary(best.legalAction.action)}`,
      reasoning: [
        best.reason,
        `该行动在当前合法行动中评分最高，适合 ${player.name} 当前资源和节奏。`,
      ],
      alternatives: scoredActions
        .slice(1, 4)
        .map((item) => `${actionSummary(item.legalAction.action)}：${item.reason}`),
      threats: threatLines(state, player),
      risks: [
        '这是本地启发式建议，只评估当前局面，没有深度搜索多回合变化。',
        '如果市场关键卡即将被对手买走，后续需要接入大模型或更强评估函数进一步判断。',
      ],
    },
  };
}
