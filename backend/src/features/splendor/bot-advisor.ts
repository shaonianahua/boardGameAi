import { cardById, nobleById } from './catalog.js';
import type {
  GemColor,
  SplendorAction,
  SplendorGameState,
  SplendorLegalAction,
  SplendorLegalActionsResult,
  SplendorPlayerState,
  TokenColor,
  TokenSet,
} from './types.js';

const gemColors: GemColor[] = ['white', 'blue', 'green', 'red', 'black'];
const tokenColors: TokenColor[] = ['white', 'blue', 'green', 'red', 'black', 'gold'];

export interface SplendorBotDecision {
  legalAction: SplendorLegalAction;
  score: number;
  reason: string;
}

function tokenTotal(tokens: TokenSet): number {
  return tokenColors.reduce((sum, color) => sum + (tokens[color] ?? 0), 0);
}

function playerTokenTotal(player: SplendorPlayerState): number {
  return tokenColors.reduce((sum, color) => sum + player.tokens[color], 0);
}

function playerBonusTotal(player: SplendorPlayerState): number {
  return gemColors.reduce((sum, color) => sum + player.bonuses[color], 0);
}

function cardCostAfterBonus(player: SplendorPlayerState, cardId: string): number {
  const card = cardById.get(cardId);
  if (!card) return 99;

  return gemColors.reduce((sum, color) => {
    return sum + Math.max(0, card.cost[color] - player.bonuses[color]);
  }, 0);
}

function nobleProgressScore(state: SplendorGameState, player: SplendorPlayerState): number {
  return state.nobles.reduce((bestScore, nobleId) => {
    const noble = nobleById.get(nobleId);
    if (!noble) return bestScore;

    const matched = gemColors.reduce((sum, color) => {
      return sum + Math.min(player.bonuses[color], noble.requirement[color]);
    }, 0);
    const required = gemColors.reduce((sum, color) => sum + noble.requirement[color], 0);
    return Math.max(bestScore, matched / Math.max(required, 1));
  }, 0);
}

function scoreBuyAction(
  state: SplendorGameState,
  player: SplendorPlayerState,
  action: Extract<SplendorAction, { type: 'buy_card' }>,
): SplendorBotDecisionScore {
  const card = cardById.get(action.cardId);
  if (!card) {
    return { score: 0, reason: '购买未知卡牌' };
  }

  const levelScore = card.level * 1.5;
  const pointScore = card.prestige * 18;
  const cheapScore = Math.max(0, 10 - cardCostAfterBonus(player, card.id));
  const nobleScore = nobleProgressScore(state, {
    ...player,
    bonuses: {
      ...player.bonuses,
      [card.bonusColor]: player.bonuses[card.bonusColor] + 1,
    },
  });
  const reservedBonus = action.source === 'reserved' ? 2 : 0;
  const finalRoundBonus = player.score + card.prestige >= 15 ? 30 : 0;

  return {
    score: 100 + pointScore + levelScore + cheapScore + nobleScore * 10 + reservedBonus + finalRoundBonus,
    reason:
      card.prestige > 0
        ? `购买 ${card.prestige} 分发展卡，直接提升分数`
        : `购买低成本发展卡，增加 ${card.bonusColor} 折扣`,
  };
}

function scoreReserveAction(
  player: SplendorPlayerState,
  action: Extract<SplendorAction, { type: 'reserve_card' }>,
): SplendorBotDecisionScore {
  const tokenCount = playerTokenTotal(player);
  const bonusCount = playerBonusTotal(player);
  const earlyGamePenalty = tokenCount < 4 && bonusCount === 0 ? 24 : 0;
  const reserveCrowdingPenalty = player.reservedCards.length * 18;

  if (action.source === 'deck') {
    return {
      score: 2 + action.level - reserveCrowdingPenalty - earlyGamePenalty,
      reason: `从 ${action.level} 级牌堆盲抽预留，保留后续机会`,
    };
  }

  const card = action.cardId ? cardById.get(action.cardId) : null;
  if (!card) {
    return { score: 6, reason: '预留一张公开发展卡' };
  }

  const highValueBonus = card.prestige >= 3 ? card.prestige * 6 + card.level : 0;
  const lowValuePenalty = card.prestige === 0 ? 12 : 0;

  return {
    score:
      10 +
      highValueBonus -
      lowValuePenalty -
      reserveCrowdingPenalty -
      earlyGamePenalty,
    reason:
      card.prestige > 0
        ? `预留 ${card.prestige} 分发展卡，避免被其他玩家抢走`
        : `预留 ${card.bonusColor} 发展卡，为后续购买做准备`,
  };
}

function scoreTakeTokensAction(
  action: Extract<SplendorAction, { type: 'take_tokens' }>,
): SplendorBotDecisionScore {
  const count = tokenTotal(action.tokens);
  const differentColorBonus = Object.values(action.tokens).filter((amount) => (amount ?? 0) > 0).length;
  return {
    score: 42 + count * 6 + differentColorBonus,
    reason: `拿取 ${count} 个宝石，积累购买资源`,
  };
}

function scoreDiscardTokensAction(
  action: Extract<SplendorAction, { type: 'discard_tokens' }>,
): SplendorBotDecisionScore {
  const goldPenalty = (action.tokens.gold ?? 0) * 20;
  const normalDiscardCount = tokenTotal(action.tokens) - (action.tokens.gold ?? 0);
  return {
    score: 50 + normalDiscardCount * 2 - goldPenalty,
    reason: '弃掉多余宝石，让回合合法结束',
  };
}

interface SplendorBotDecisionScore {
  score: number;
  reason: string;
}

function scoreAction(
  state: SplendorGameState,
  player: SplendorPlayerState,
  legalAction: SplendorLegalAction,
): SplendorBotDecision {
  const action = legalAction.action;
  const result = (() => {
    if (action.type === 'buy_card') {
      return scoreBuyAction(state, player, action);
    }
    if (action.type === 'reserve_card') {
      return scoreReserveAction(player, action);
    }
    if (action.type === 'take_tokens') {
      return scoreTakeTokensAction(action);
    }
    if (action.type === 'discard_tokens') {
      return scoreDiscardTokensAction(action);
    }
    return { score: 0, reason: legalAction.label };
  })();

  return {
    legalAction,
    score: result.score,
    reason: result.reason,
  };
}

/// 从后端规则引擎生成的合法行动中挑选一个本地 Bot 行动。
///
/// 当前是 V2 第一版启发式：优先购买得分卡，其次铺折扣、预留高分卡，再拿宝石。
/// 它只选择合法行动，不直接修改 `GameState`，最终仍由规则引擎执行和校验。
export function chooseSplendorBotAction(
  state: SplendorGameState,
  legalActions: SplendorLegalActionsResult,
): SplendorBotDecision {
  const player = state.players[legalActions.playerIndex];
  if (!player) {
    throw new Error('bot player not found');
  }
  if (legalActions.actions.length === 0) {
    throw new Error(legalActions.disabledReasons[0] ?? 'bot has no legal action');
  }

  return legalActions.actions
    .map((legalAction) => scoreAction(state, player, legalAction))
    .sort((left, right) => {
      if (right.score !== left.score) return right.score - left.score;
      return left.legalAction.label.localeCompare(right.legalAction.label);
    })[0];
}
