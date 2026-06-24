import { splendorCards, splendorNobles } from './catalog.js';
import type {
  CreateSplendorSessionInput,
  FullTokenSet,
  GemSet,
  SplendorGameState,
  SplendorPlayerState,
} from './types.js';

const emptyTokens = (): FullTokenSet => ({
  white: 0,
  blue: 0,
  green: 0,
  red: 0,
  black: 0,
  gold: 0,
});

const emptyBonuses = (): GemSet => ({
  white: 0,
  blue: 0,
  green: 0,
  red: 0,
  black: 0,
});

function shuffle<T>(items: T[]): T[] {
  const result = [...items];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const target = Math.floor(Math.random() * (index + 1));
    [result[index], result[target]] = [result[target], result[index]];
  }
  return result;
}

function normalTokenCount(playerCount: number): number {
  if (playerCount === 2) return 4;
  if (playerCount === 3) return 5;
  return 7;
}

function initialPlayers(input: CreateSplendorSessionInput): SplendorPlayerState[] {
  return input.players.map((player, index) => ({
    seatIndex: index,
    name: player.name.trim() || `玩家${index + 1}`,
    type: player.type ?? 'human',
    botLevel: (player.type ?? 'human') === 'bot' ? player.botLevel ?? 'local' : undefined,
    score: 0,
    tokens: emptyTokens(),
    bonuses: emptyBonuses(),
    purchasedCards: [],
    reservedCards: [],
    nobles: [],
  }));
}

export function createInitialSplendorState(input: CreateSplendorSessionInput): SplendorGameState {
  if (!Number.isInteger(input.playerCount) || input.playerCount < 2 || input.playerCount > 4) {
    throw new Error('playerCount must be between 2 and 4');
  }
  if (input.players.length !== input.playerCount) {
    throw new Error('players length must match playerCount');
  }

  const tokenCount = normalTokenCount(input.playerCount);
  const level1 = shuffle(splendorCards.filter((card) => card.level === 1).map((card) => card.id));
  const level2 = shuffle(splendorCards.filter((card) => card.level === 2).map((card) => card.id));
  const level3 = shuffle(splendorCards.filter((card) => card.level === 3).map((card) => card.id));
  const nobles = shuffle(splendorNobles.map((noble) => noble.id)).slice(0, input.playerCount + 1);

  return {
    gameType: 'splendor',
    status: 'active',
    playerCount: input.playerCount,
    currentTurnIndex: 0,
    currentPlayerIndex: 0,
    tokenPool: {
      white: tokenCount,
      blue: tokenCount,
      green: tokenCount,
      red: tokenCount,
      black: tokenCount,
      gold: 5,
    },
    markets: {
      level1: level1.splice(0, 4),
      level2: level2.splice(0, 4),
      level3: level3.splice(0, 4),
    },
    decks: {
      level1,
      level2,
      level3,
    },
    nobles,
    players: initialPlayers(input),
    finalRound: {
      triggered: false,
      triggeredByPlayerIndex: null,
      roundEndPlayerIndex: null,
    },
    pendingAction: null,
    winnerPlayerIndex: null,
  };
}

export function parseState(stateJson: string): SplendorGameState {
  return JSON.parse(stateJson) as SplendorGameState;
}

export function stringifyState(state: SplendorGameState): string {
  return JSON.stringify(state);
}
