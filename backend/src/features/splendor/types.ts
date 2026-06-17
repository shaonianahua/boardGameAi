export type GemColor = 'white' | 'blue' | 'green' | 'red' | 'black';
export type TokenColor = GemColor | 'gold';
export type PlayerType = 'human' | 'bot';
export type SessionStatus = 'active' | 'finished' | 'abandoned';
export type ActionActorType = 'human' | 'bot' | 'llm';

export type TokenSet = Partial<Record<TokenColor, number>>;
export type GemSet = Record<GemColor, number>;
export type FullTokenSet = Record<TokenColor, number>;

export interface SplendorCard {
  id: string;
  level: 1 | 2 | 3;
  bonusColor: GemColor;
  prestige: number;
  cost: GemSet;
}

export interface SplendorNoble {
  id: string;
  prestige: number;
  requirement: GemSet;
}

export interface SplendorPlayerState {
  seatIndex: number;
  name: string;
  type: PlayerType;
  botLevel?: string;
  score: number;
  tokens: FullTokenSet;
  bonuses: GemSet;
  purchasedCards: string[];
  reservedCards: string[];
  nobles: string[];
}

export interface SplendorGameState {
  gameType: 'splendor';
  status: SessionStatus;
  playerCount: number;
  currentTurnIndex: number;
  currentPlayerIndex: number;
  tokenPool: FullTokenSet;
  markets: {
    level1: string[];
    level2: string[];
    level3: string[];
  };
  decks: {
    level1: string[];
    level2: string[];
    level3: string[];
  };
  nobles: string[];
  players: SplendorPlayerState[];
  finalRound: {
    triggered: boolean;
    triggeredByPlayerIndex: number | null;
    roundEndPlayerIndex: number | null;
  };
  pendingAction: SplendorPendingAction | null;
  winnerPlayerIndex: number | null;
}

export type SplendorPendingAction =
  | {
      type: 'discard_tokens';
      playerIndex: number;
      tokenCount: number;
      maxTokenCount: number;
    }
  | {
      type: 'choose_noble';
      playerIndex: number;
      nobleIds: string[];
    };

export interface CreateSplendorSessionInput {
  playerCount: number;
  title?: string;
  players: Array<{
    name: string;
    type?: PlayerType;
    botLevel?: string;
  }>;
}

export type SplendorAction =
  | {
      type: 'take_tokens';
      tokens: TokenSet;
    }
  | {
      type: 'reserve_card';
      source: 'market' | 'deck';
      cardId?: string;
      level: 1 | 2 | 3;
    }
  | {
      type: 'buy_card';
      source: 'market' | 'reserved';
      cardId: string;
      payment?: TokenSet;
    }
  | {
      type: 'discard_tokens';
      tokens: TokenSet;
    }
  | {
      type: 'choose_noble';
      nobleId: string;
    }
  | {
      type: 'noble_visit';
      nobleId: string;
    };

export interface SubmitSplendorActionInput {
  playerIndex: number;
  actorType?: ActionActorType;
  action: SplendorAction;
}

export interface SplendorLegalAction {
  action: SplendorAction;
  label: string;
}

export interface SplendorLegalActionsResult {
  playerIndex: number;
  pendingAction: SplendorPendingAction | null;
  actions: SplendorLegalAction[];
  disabledReasons: string[];
}
