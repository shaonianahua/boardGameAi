import type { SplendorAdviceDecision } from '../advisor-service.js';
import type {
  SplendorGameState,
  SplendorLegalAction,
  SplendorPlayerState,
} from '../types.js';

export type SplendorAdvisorGameState = Omit<SplendorGameState, 'decks'> & {
  decks: {
    level1Count: number;
    level2Count: number;
    level3Count: number;
  };
  players: Array<
    Pick<
      SplendorPlayerState,
      | 'seatIndex'
      | 'name'
      | 'type'
      | 'score'
      | 'tokens'
      | 'bonuses'
      | 'purchasedCards'
      | 'reservedCards'
      | 'nobles'
    >
  >;
};

/// AI 建议模型输入。
///
/// Provider 只能基于后端已经枚举出的合法行动做选择，不能自行创造行动。
export interface SplendorAdvisorInput {
  gameState: SplendorAdvisorGameState;
  catalog: {
    cards: unknown[];
    nobles: unknown[];
  };
  legalActions: Array<{
    actionId: string;
    label: string;
    action: SplendorLegalAction['action'];
  }>;
  currentPlayerIndex: number;
  style: string;
}

/// AI Provider 统一接口。
///
/// DeepSeek、本地模型或其它云模型都实现这个接口，方便 advisor-service 做 fallback。
export interface SplendorAiProvider {
  decide(input: SplendorAdvisorInput): Promise<SplendorAdviceDecision>;
}
