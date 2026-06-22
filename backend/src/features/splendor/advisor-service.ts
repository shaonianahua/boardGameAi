import { cardById, nobleById } from './catalog.js';
import { scoreSplendorLegalAction } from './bot-advisor.js';
import type { SplendorAdvisorInput, SplendorAiProvider } from './ai/ai-provider.js';
import { DeepSeekSplendorProvider } from './ai/deepseek-provider.js';
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

export type SplendorAdviceStreamEvent =
  | { type: 'progress'; text: string }
  | { type: 'delta'; text: string }
  | { type: 'result'; response: SplendorAdviceResponse }
  | { type: 'done' };

interface ScoredLegalAction {
  actionId: string;
  legalAction: SplendorLegalAction;
  score: number;
  reason: string;
}

export function actionStableKey(action: SplendorAction): string {
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

function createScoredActions(
  state: SplendorGameState,
  legalActions: SplendorLegalActionsResult,
): ScoredLegalAction[] {
  const player = state.players[legalActions.playerIndex];
  if (!player) {
    throw new Error('advice player not found');
  }

  return legalActions.actions
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
}

/// 使用本地启发式生成 AI 建议接口 fallback 输出。
///
/// 模型未配置、超时、返回非法 JSON 或推荐非法 actionId 时都会回退到这里。
export function createHeuristicSplendorAdvice(
  state: SplendorGameState,
  legalActions: SplendorLegalActionsResult,
  fallbackReason?: string,
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

  const scoredActions = createScoredActions(state, legalActions);
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
        ...(fallbackReason ? [`模型建议暂不可用，已回退本地启发式：${fallbackReason}`] : []),
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

/// 生成 AI 建议：优先调用 DeepSeek，失败时回退本地启发式。
///
/// 这里不执行行动，只把模型返回的 actionId 映射回后端合法行动，保证前端只能看到可执行建议。
export async function createSplendorAdvice(
  state: SplendorGameState,
  legalActions: SplendorLegalActionsResult,
): Promise<SplendorAdviceResponse> {
  const provider = createConfiguredProvider();
  if (!provider) {
    return createHeuristicSplendorAdvice(state, legalActions, '未配置 DeepSeek API Key');
  }
  if (legalActions.actions.length === 0) {
    return createHeuristicSplendorAdvice(state, legalActions);
  }

  try {
    const input = createAdvisorInput(state, legalActions);
    console.info(
      `[splendor.ai] request provider=${provider.constructor.name} ` +
      `player=${legalActions.playerIndex} legalActions=${input.legalActions.length} ` +
      `catalogCards=${input.catalog.cards.length} nobles=${input.catalog.nobles.length}`,
    );
    const startedAt = Date.now();
    const result = provider instanceof DeepSeekSplendorProvider
      ? await provider.decideWithMetadata(input)
      : { decision: await provider.decide(input), usage: null };
    const decision = result.decision;
    const selectedAction = decision.actionId == null
      ? null
      : legalActions.actions.find((legalAction) => actionStableKey(legalAction.action) === decision.actionId) ?? null;
    if (decision.actionId != null && selectedAction == null) {
      throw new Error(`model selected unavailable action: ${decision.actionId}`);
    }
    console.info(
      `[splendor.ai] success provider=${provider.constructor.name} ` +
      `actionId=${decision.actionId ?? 'null'} confidence=${decision.confidence} ` +
      `durationMs=${Date.now() - startedAt} ` +
      `tokens=${formatUsage(result.usage)}`,
    );
    return { decision, selectedAction };
  } catch (error) {
    const reason = errorMessage(error);
    console.warn('[splendor.ai] DeepSeek advice failed, fallback to heuristic:', reason);
    return createHeuristicSplendorAdvice(state, legalActions, reason);
  }
}

/// 生成 AI 建议流式事件。
///
/// 优先消费 DeepSeek 原生 stream:true 输出：自然语言分析会边生成边转发，
/// 最终 JSON 在后端拼完整后校验，并以 result 事件返回结构化建议。
export async function* createSplendorAdviceStream(
  state: SplendorGameState,
  legalActions: SplendorLegalActionsResult,
): AsyncGenerator<SplendorAdviceStreamEvent> {
  yield { type: 'progress', text: '正在读取当前桌面、玩家资源和公开卡牌。' };
  yield { type: 'progress', text: `已找到 ${legalActions.actions.length} 个当前合法行动。` };

  const provider = createConfiguredProvider();
  if (!provider || !(provider instanceof DeepSeekSplendorProvider) || legalActions.actions.length === 0) {
    const advice = createHeuristicSplendorAdvice(
      state,
      legalActions,
      !provider ? '未配置 DeepSeek API Key' : undefined,
    );
    yield { type: 'delta', text: `结论：${advice.decision.summary}` };
    yield { type: 'result', response: advice };
    yield { type: 'done' };
    return;
  }

  try {
    const input = createAdvisorInput(state, legalActions);
    const startedAt = Date.now();
    console.info(
      `[splendor.ai] stream request provider=${provider.constructor.name} ` +
      `player=${legalActions.playerIndex} legalActions=${input.legalActions.length} ` +
      `catalogCards=${input.catalog.cards.length} nobles=${input.catalog.nobles.length}`,
    );
    yield { type: 'progress', text: '模型已开始实时分析。' };

    for await (const event of provider.decideStreamWithMetadata(input)) {
      if (event.type === 'delta') {
        yield { type: 'delta', text: event.text };
        continue;
      }

      const decision = event.result.decision;
      const selectedAction = decision.actionId == null
        ? null
        : legalActions.actions.find((legalAction) => actionStableKey(legalAction.action) === decision.actionId) ?? null;
      if (decision.actionId != null && selectedAction == null) {
        throw new Error(`model selected unavailable action: ${decision.actionId}`);
      }
      console.info(
        `[splendor.ai] stream success provider=${provider.constructor.name} ` +
        `actionId=${decision.actionId ?? 'null'} confidence=${decision.confidence} ` +
        `durationMs=${Date.now() - startedAt} ` +
        `tokens=${formatUsage(event.result.usage)}`,
      );
      yield { type: 'result', response: { decision, selectedAction } };
    }
  } catch (error) {
    const reason = errorMessage(error);
    console.warn('[splendor.ai] DeepSeek stream failed, fallback to heuristic:', reason);
    const advice = createHeuristicSplendorAdvice(state, legalActions, reason);
    yield { type: 'delta', text: `模型流式建议暂不可用，已切换为本地建议：${advice.decision.summary}` };
    yield { type: 'result', response: advice };
  }
  yield { type: 'done' };
}

function createConfiguredProvider(): SplendorAiProvider | null {
  const provider = process.env.AI_PROVIDER ?? 'deepseek';
  const apiKey = process.env.DEEPSEEK_API_KEY;
  if (provider !== 'deepseek' || !apiKey) {
    return null;
  }

  return new DeepSeekSplendorProvider({
    apiKey,
    baseUrl: process.env.DEEPSEEK_BASE_URL ?? 'https://api.deepseek.com',
    model: process.env.DEEPSEEK_MODEL ?? 'deepseek-v4-flash',
    timeoutMs: Number(process.env.DEEPSEEK_TIMEOUT_MS ?? 180000),
  });
}

function createAdvisorInput(
  state: SplendorGameState,
  legalActions: SplendorLegalActionsResult,
): SplendorAdvisorInput {
  const scoredActions = createScoredActions(state, legalActions);
  return {
    gameState: createAdvisorGameState(state),
    catalog: createRelevantCatalog(state),
    legalActions: scoredActions.map((item) => ({
      actionId: item.actionId,
      label: `${item.legalAction.label} | heuristic=${item.score.toFixed(1)} | ${item.reason}`,
      action: item.legalAction.action,
    })),
    currentPlayerIndex: legalActions.playerIndex,
    style: process.env.SPLENDOR_AI_STYLE ?? 'balanced',
  };
}

function createAdvisorGameState(state: SplendorGameState): SplendorAdvisorInput['gameState'] {
  return {
    ...state,
    decks: {
      level1Count: state.decks.level1.length,
      level2Count: state.decks.level2.length,
      level3Count: state.decks.level3.length,
    },
    players: state.players.map((player) => ({
      seatIndex: player.seatIndex,
      name: player.name,
      type: player.type,
      score: player.score,
      tokens: player.tokens,
      bonuses: player.bonuses,
      purchasedCards: player.purchasedCards,
      reservedCards: player.reservedCards,
      nobles: player.nobles,
    })),
  };
}

function createRelevantCatalog(state: SplendorGameState): SplendorAdvisorInput['catalog'] {
  const cardIds = new Set<string>([
    ...state.markets.level1,
    ...state.markets.level2,
    ...state.markets.level3,
    ...state.players.flatMap((player) => [
      ...player.purchasedCards,
      ...player.reservedCards,
    ]),
  ]);

  return {
    cards: [...cardIds]
      .map((cardId) => cardById.get(cardId))
      .filter((card): card is NonNullable<typeof card> => card != null),
    nobles: state.nobles
      .map((nobleId) => nobleById.get(nobleId))
      .filter((noble): noble is NonNullable<typeof noble> => noble != null),
  };
}

function errorMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : 'unknown model error';
  return message.replace(/\s+/g, ' ').slice(0, 300);
}

function formatUsage(
  usage: {
    promptTokens: number | null;
    completionTokens: number | null;
    totalTokens: number | null;
  } | null,
): string {
  if (!usage) {
    return 'unknown';
  }
  return `prompt:${usage.promptTokens ?? '?'} completion:${usage.completionTokens ?? '?'} total:${usage.totalTokens ?? '?'}`;
}
