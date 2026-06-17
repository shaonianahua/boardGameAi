import { cardById, nobleById } from './catalog.js';
import type {
  FullTokenSet,
  GemColor,
  SplendorAction,
  SplendorGameState,
  SplendorPlayerState,
  TokenColor,
  TokenSet,
} from './types.js';

const gemColors: GemColor[] = ['white', 'blue', 'green', 'red', 'black'];
const tokenColors: TokenColor[] = ['white', 'blue', 'green', 'red', 'black', 'gold'];

const totalTokens = (tokens: FullTokenSet): number =>
  tokenColors.reduce((sum, color) => sum + tokens[color], 0);

function cloneState(state: SplendorGameState): SplendorGameState {
  return JSON.parse(JSON.stringify(state)) as SplendorGameState;
}

function normalizeTokenSet(tokens: TokenSet): FullTokenSet {
  return {
    white: tokens.white ?? 0,
    blue: tokens.blue ?? 0,
    green: tokens.green ?? 0,
    red: tokens.red ?? 0,
    black: tokens.black ?? 0,
    gold: tokens.gold ?? 0,
  };
}

function assertNonNegativeTokens(tokens: TokenSet): void {
  for (const color of Object.keys(tokens) as TokenColor[]) {
    const amount = tokens[color] ?? 0;
    if (!Number.isInteger(amount) || amount < 0) {
      throw new Error(`invalid token amount for ${color}`);
    }
  }
}

function drawReplacement(state: SplendorGameState, level: 1 | 2 | 3): void {
  const marketKey = `level${level}` as const;
  const nextCard = state.decks[marketKey].shift();
  if (nextCard) {
    state.markets[marketKey].push(nextCard);
  }
}

function nextPlayer(state: SplendorGameState): void {
  const nextIndex = (state.currentPlayerIndex + 1) % state.playerCount;
  if (nextIndex === 0) {
    state.currentTurnIndex += 1;
  }
  state.currentPlayerIndex = nextIndex;
}

function assertActiveTurn(state: SplendorGameState, playerIndex: number): SplendorPlayerState {
  if (state.status !== 'active') {
    throw new Error('session is not active');
  }
  if (playerIndex !== state.currentPlayerIndex) {
    throw new Error('not current player turn');
  }
  const player = state.players[playerIndex];
  if (!player) {
    throw new Error('player not found');
  }
  return player;
}

function applyTakeTokens(state: SplendorGameState, player: SplendorPlayerState, tokens: TokenSet): void {
  assertNonNegativeTokens(tokens);
  const normalized = normalizeTokenSet(tokens);
  if (normalized.gold > 0) {
    throw new Error('gold cannot be taken directly');
  }

  const selectedColors = gemColors.filter((color) => normalized[color] > 0);
  const total = selectedColors.reduce((sum, color) => sum + normalized[color], 0);

  if (total === 3) {
    if (selectedColors.length !== 3 || selectedColors.some((color) => normalized[color] !== 1)) {
      throw new Error('taking 3 tokens requires 3 different colors');
    }
  } else if (total === 2) {
    if (selectedColors.length !== 1) {
      throw new Error('taking 2 tokens requires one color');
    }
    const color = selectedColors[0];
    if (state.tokenPool[color] < 4) {
      throw new Error('taking 2 same-color tokens requires at least 4 in pool');
    }
  } else {
    throw new Error('take_tokens must take either 2 same-color or 3 different-color tokens');
  }

  for (const color of gemColors) {
    if (state.tokenPool[color] < normalized[color]) {
      throw new Error(`not enough ${color} tokens in pool`);
    }
  }

  for (const color of gemColors) {
    state.tokenPool[color] -= normalized[color];
    player.tokens[color] += normalized[color];
  }

  if (totalTokens(player.tokens) > 10) {
    throw new Error('player token count exceeds 10; discard flow is not implemented yet');
  }
}

function removeMarketCard(state: SplendorGameState, cardId: string): 1 | 2 | 3 {
  for (const level of [1, 2, 3] as const) {
    const marketKey = `level${level}` as const;
    const index = state.markets[marketKey].indexOf(cardId);
    if (index >= 0) {
      state.markets[marketKey].splice(index, 1);
      return level;
    }
  }
  throw new Error('card is not in market');
}

function applyReserveCard(
  state: SplendorGameState,
  player: SplendorPlayerState,
  action: Extract<SplendorAction, { type: 'reserve_card' }>,
): void {
  if (player.reservedCards.length >= 3) {
    throw new Error('reserved card limit reached');
  }

  let cardId = action.cardId;
  let level = action.level;

  if (action.source === 'market') {
    if (!cardId) {
      throw new Error('cardId is required for market reservation');
    }
    level = removeMarketCard(state, cardId);
    drawReplacement(state, level);
  } else {
    const deckKey = `level${level}` as const;
    cardId = state.decks[deckKey].shift();
    if (!cardId) {
      throw new Error('deck is empty');
    }
  }

  player.reservedCards.push(cardId);
  if (state.tokenPool.gold > 0) {
    state.tokenPool.gold -= 1;
    player.tokens.gold += 1;
  }

  if (totalTokens(player.tokens) > 10) {
    throw new Error('player token count exceeds 10; discard flow is not implemented yet');
  }
}

function canPay(player: SplendorPlayerState, cardId: string, payment: FullTokenSet): boolean {
  const card = cardById.get(cardId);
  if (!card) return false;

  for (const color of tokenColors) {
    if (payment[color] > player.tokens[color]) {
      return false;
    }
  }

  let requiredGold = 0;
  for (const color of gemColors) {
    const discountedCost = Math.max(0, card.cost[color] - player.bonuses[color]);
    const paid = payment[color];
    if (paid > discountedCost) {
      return false;
    }
    requiredGold += discountedCost - paid;
  }

  return payment.gold === requiredGold;
}

function defaultPayment(player: SplendorPlayerState, cardId: string): FullTokenSet {
  const card = cardById.get(cardId);
  if (!card) {
    throw new Error('card not found');
  }
  const payment = normalizeTokenSet({});
  let missing = 0;

  for (const color of gemColors) {
    const discountedCost = Math.max(0, card.cost[color] - player.bonuses[color]);
    const paid = Math.min(player.tokens[color], discountedCost);
    payment[color] = paid;
    missing += discountedCost - paid;
  }
  payment.gold = missing;
  return payment;
}

function applyBuyCard(
  state: SplendorGameState,
  player: SplendorPlayerState,
  action: Extract<SplendorAction, { type: 'buy_card' }>,
): void {
  const card = cardById.get(action.cardId);
  if (!card) {
    throw new Error('card not found');
  }

  let purchasedFromMarketLevel: 1 | 2 | 3 | null = null;
  if (action.source === 'market') {
    purchasedFromMarketLevel = removeMarketCard(state, action.cardId);
  } else {
    const index = player.reservedCards.indexOf(action.cardId);
    if (index < 0) {
      throw new Error('card is not reserved by player');
    }
    player.reservedCards.splice(index, 1);
  }

  const payment = normalizeTokenSet(action.payment ?? defaultPayment(player, action.cardId));
  assertNonNegativeTokens(payment);
  if (!canPay(player, action.cardId, payment)) {
    throw new Error('payment cannot cover card cost');
  }

  for (const color of tokenColors) {
    player.tokens[color] -= payment[color];
    state.tokenPool[color] += payment[color];
  }

  player.purchasedCards.push(action.cardId);
  player.bonuses[card.bonusColor] += 1;
  player.score += card.prestige;

  if (purchasedFromMarketLevel) {
    drawReplacement(state, purchasedFromMarketLevel);
  }
}

function applyNobleVisits(state: SplendorGameState, player: SplendorPlayerState): void {
  const visitingNobleId = state.nobles.find((nobleId) => {
    const noble = nobleById.get(nobleId);
    if (!noble) return false;
    return gemColors.every((color) => player.bonuses[color] >= noble.requirement[color]);
  });

  if (!visitingNobleId) {
    return;
  }

  const noble = nobleById.get(visitingNobleId);
  if (!noble) {
    return;
  }

  state.nobles = state.nobles.filter((nobleId) => nobleId !== visitingNobleId);
  player.nobles.push(visitingNobleId);
  player.score += noble.prestige;
}

function updateFinalRound(state: SplendorGameState, player: SplendorPlayerState): void {
  if (!state.finalRound.triggered && player.score >= 15) {
    state.finalRound.triggered = true;
    state.finalRound.triggeredByPlayerIndex = player.seatIndex;
    state.finalRound.roundEndPlayerIndex = state.playerCount - 1;
  }

  if (
    state.finalRound.triggered &&
    state.currentPlayerIndex === state.finalRound.roundEndPlayerIndex
  ) {
    state.status = 'finished';
    state.winnerPlayerIndex = pickWinner(state);
  }
}

function pickWinner(state: SplendorGameState): number {
  const sorted = [...state.players].sort((left, right) => {
    if (right.score !== left.score) return right.score - left.score;
    return left.purchasedCards.length - right.purchasedCards.length;
  });
  return sorted[0].seatIndex;
}

export function applySplendorAction(
  inputState: SplendorGameState,
  playerIndex: number,
  action: SplendorAction,
): SplendorGameState {
  const state = cloneState(inputState);
  const player = assertActiveTurn(state, playerIndex);

  if (action.type === 'take_tokens') {
    applyTakeTokens(state, player, action.tokens);
  } else if (action.type === 'reserve_card') {
    applyReserveCard(state, player, action);
  } else if (action.type === 'buy_card') {
    applyBuyCard(state, player, action);
  } else if (action.type === 'discard_tokens') {
    throw new Error('discard_tokens is not implemented as standalone action yet');
  } else if (action.type === 'choose_noble') {
    throw new Error('choose_noble is not implemented as standalone action yet');
  } else {
    throw new Error('unsupported action type');
  }

  applyNobleVisits(state, player);
  updateFinalRound(state, player);
  if (state.status === 'active') {
    nextPlayer(state);
  }

  return state;
}

export function actionType(action: SplendorAction): string {
  return action.type;
}

