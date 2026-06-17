import { cardById, nobleById } from './catalog.js';
import type {
  FullTokenSet,
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
const maxPlayerTokenCount = 10;

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

function assertNoPendingAction(state: SplendorGameState): void {
  if (state.pendingAction) {
    throw new Error(`pending ${state.pendingAction.type} must be resolved first`);
  }
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

function canAfford(player: SplendorPlayerState, cardId: string): boolean {
  return canPay(player, cardId, defaultPayment(player, cardId));
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

  const payment = normalizeTokenSet(action.payment ?? defaultPayment(player, action.cardId));
  assertNonNegativeTokens(payment);
  if (!canPay(player, action.cardId, payment)) {
    throw new Error('payment cannot cover card cost');
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

function eligibleNobleIds(state: SplendorGameState, player: SplendorPlayerState): string[] {
  return state.nobles.filter((nobleId) => {
    const noble = nobleById.get(nobleId);
    if (!noble) return false;
    return gemColors.every((color) => player.bonuses[color] >= noble.requirement[color]);
  });
}

function awardNoble(state: SplendorGameState, player: SplendorPlayerState, nobleId: string): void {
  const noble = nobleById.get(nobleId);
  if (!noble) {
    throw new Error('noble not found');
  }
  if (!state.nobles.includes(nobleId)) {
    throw new Error('noble is not available');
  }

  state.nobles = state.nobles.filter((availableNobleId) => availableNobleId !== nobleId);
  player.nobles.push(nobleId);
  player.score += noble.prestige;
}

function resolveNobleVisits(state: SplendorGameState, player: SplendorPlayerState): void {
  const eligible = eligibleNobleIds(state, player);
  if (eligible.length === 0) {
    return;
  }
  if (eligible.length === 1) {
    awardNoble(state, player, eligible[0]);
    return;
  }

  state.pendingAction = {
    type: 'choose_noble',
    playerIndex: player.seatIndex,
    nobleIds: eligible,
  };
}

function setDiscardPendingIfNeeded(state: SplendorGameState, player: SplendorPlayerState): void {
  const tokenCount = totalTokens(player.tokens);
  if (tokenCount <= maxPlayerTokenCount) {
    return;
  }

  state.pendingAction = {
    type: 'discard_tokens',
    playerIndex: player.seatIndex,
    tokenCount,
    maxTokenCount: maxPlayerTokenCount,
  };
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

function finishActionIfNoPending(state: SplendorGameState, player: SplendorPlayerState): void {
  if (state.pendingAction) {
    return;
  }

  updateFinalRound(state, player);
  if (state.status === 'active') {
    nextPlayer(state);
  }
}

function applyDiscardTokens(
  state: SplendorGameState,
  player: SplendorPlayerState,
  tokens: TokenSet,
): void {
  const pending = state.pendingAction;
  if (!pending || pending.type !== 'discard_tokens') {
    throw new Error('no discard_tokens action is pending');
  }
  if (pending.playerIndex !== player.seatIndex) {
    throw new Error('pending discard_tokens belongs to another player');
  }

  assertNonNegativeTokens(tokens);
  const normalized = normalizeTokenSet(tokens);
  const discardCount = totalTokens(normalized);
  const requiredDiscardCount = pending.tokenCount - pending.maxTokenCount;
  if (discardCount !== requiredDiscardCount) {
    throw new Error(`must discard exactly ${requiredDiscardCount} token(s)`);
  }

  for (const color of tokenColors) {
    if (normalized[color] > player.tokens[color]) {
      throw new Error(`not enough ${color} tokens to discard`);
    }
  }

  for (const color of tokenColors) {
    player.tokens[color] -= normalized[color];
    state.tokenPool[color] += normalized[color];
  }

  if (totalTokens(player.tokens) !== pending.maxTokenCount) {
    throw new Error('discard must leave player with exactly 10 tokens');
  }

  state.pendingAction = null;
}

function applyChooseNoble(
  state: SplendorGameState,
  player: SplendorPlayerState,
  nobleId: string,
): void {
  const pending = state.pendingAction;
  if (!pending || pending.type !== 'choose_noble') {
    throw new Error('no choose_noble action is pending');
  }
  if (pending.playerIndex !== player.seatIndex) {
    throw new Error('pending choose_noble belongs to another player');
  }
  if (!pending.nobleIds.includes(nobleId)) {
    throw new Error('noble is not eligible');
  }

  awardNoble(state, player, nobleId);
  state.pendingAction = null;
}

export function applySplendorAction(
  inputState: SplendorGameState,
  playerIndex: number,
  action: SplendorAction,
): SplendorGameState {
  const state = cloneState(inputState);
  const player = assertActiveTurn(state, playerIndex);

  if (action.type === 'discard_tokens') {
    applyDiscardTokens(state, player, action.tokens);
    finishActionIfNoPending(state, player);
    return state;
  }

  if (action.type === 'choose_noble') {
    applyChooseNoble(state, player, action.nobleId);
    finishActionIfNoPending(state, player);
    return state;
  }

  assertNoPendingAction(state);

  if (action.type === 'take_tokens') {
    applyTakeTokens(state, player, action.tokens);
    setDiscardPendingIfNeeded(state, player);
  } else if (action.type === 'reserve_card') {
    applyReserveCard(state, player, action);
    setDiscardPendingIfNeeded(state, player);
  } else if (action.type === 'buy_card') {
    applyBuyCard(state, player, action);
    resolveNobleVisits(state, player);
  } else {
    throw new Error('unsupported action type');
  }

  finishActionIfNoPending(state, player);
  return state;
}

export function actionType(action: SplendorAction): string {
  return action.type;
}

function tokenSetFromEntries(entries: Array<[TokenColor, number]>): TokenSet {
  return entries.reduce<TokenSet>((tokens, [color, amount]) => {
    if (amount > 0) {
      tokens[color] = amount;
    }
    return tokens;
  }, {});
}

function discardCombinations(tokens: FullTokenSet, count: number): TokenSet[] {
  const results: TokenSet[] = [];

  function visit(colorIndex: number, remaining: number, entries: Array<[TokenColor, number]>): void {
    if (colorIndex === tokenColors.length) {
      if (remaining === 0) {
        results.push(tokenSetFromEntries(entries));
      }
      return;
    }

    const color = tokenColors[colorIndex];
    const maxAmount = Math.min(tokens[color], remaining);
    for (let amount = 0; amount <= maxAmount; amount += 1) {
      visit(colorIndex + 1, remaining - amount, [...entries, [color, amount]]);
    }
  }

  visit(0, count, []);
  return results;
}

function appendTakeTokenActions(state: SplendorGameState, actions: SplendorLegalAction[]): void {
  for (let left = 0; left < gemColors.length; left += 1) {
    for (let middle = left + 1; middle < gemColors.length; middle += 1) {
      for (let right = middle + 1; right < gemColors.length; right += 1) {
        const colors = [gemColors[left], gemColors[middle], gemColors[right]];
        if (colors.every((color) => state.tokenPool[color] > 0)) {
          actions.push({
            action: {
              type: 'take_tokens',
              tokens: tokenSetFromEntries(colors.map((color) => [color, 1])),
            },
            label: `Take ${colors.join(', ')}`,
          });
        }
      }
    }
  }

  for (const color of gemColors) {
    if (state.tokenPool[color] >= 4) {
      actions.push({
        action: {
          type: 'take_tokens',
          tokens: { [color]: 2 },
        },
        label: `Take 2 ${color}`,
      });
    }
  }
}

function appendReserveActions(
  state: SplendorGameState,
  player: SplendorPlayerState,
  actions: SplendorLegalAction[],
): void {
  if (player.reservedCards.length >= 3) {
    return;
  }

  for (const level of [1, 2, 3] as const) {
    const marketKey = `level${level}` as const;
    for (const cardId of state.markets[marketKey]) {
      actions.push({
        action: {
          type: 'reserve_card',
          source: 'market',
          level,
          cardId,
        },
        label: `Reserve ${cardId}`,
      });
    }

    if (state.decks[marketKey].length > 0) {
      actions.push({
        action: {
          type: 'reserve_card',
          source: 'deck',
          level,
        },
        label: `Reserve blind level ${level}`,
      });
    }
  }
}

function appendBuyActions(
  state: SplendorGameState,
  player: SplendorPlayerState,
  actions: SplendorLegalAction[],
): void {
  for (const level of [1, 2, 3] as const) {
    const marketKey = `level${level}` as const;
    for (const cardId of state.markets[marketKey]) {
      if (canAfford(player, cardId)) {
        actions.push({
          action: {
            type: 'buy_card',
            source: 'market',
            cardId,
          },
          label: `Buy ${cardId}`,
        });
      }
    }
  }

  for (const cardId of player.reservedCards) {
    if (canAfford(player, cardId)) {
      actions.push({
        action: {
          type: 'buy_card',
          source: 'reserved',
          cardId,
        },
        label: `Buy reserved ${cardId}`,
      });
    }
  }
}

export function generateSplendorLegalActions(
  state: SplendorGameState,
): SplendorLegalActionsResult {
  const playerIndex = state.currentPlayerIndex;
  const player = state.players[playerIndex];
  const disabledReasons: string[] = [];
  const actions: SplendorLegalAction[] = [];

  if (state.status !== 'active') {
    return {
      playerIndex,
      pendingAction: state.pendingAction,
      actions,
      disabledReasons: ['session is not active'],
    };
  }

  if (!player) {
    return {
      playerIndex,
      pendingAction: state.pendingAction,
      actions,
      disabledReasons: ['current player not found'],
    };
  }

  if (state.pendingAction?.type === 'discard_tokens') {
    const requiredDiscardCount =
      state.pendingAction.tokenCount - state.pendingAction.maxTokenCount;
    for (const tokens of discardCombinations(player.tokens, requiredDiscardCount)) {
      actions.push({
        action: {
          type: 'discard_tokens',
          tokens,
        },
        label: 'Discard tokens',
      });
    }
    return {
      playerIndex,
      pendingAction: state.pendingAction,
      actions,
      disabledReasons,
    };
  }

  if (state.pendingAction?.type === 'choose_noble') {
    for (const nobleId of state.pendingAction.nobleIds) {
      actions.push({
        action: {
          type: 'choose_noble',
          nobleId,
        },
        label: `Choose ${nobleId}`,
      });
    }
    return {
      playerIndex,
      pendingAction: state.pendingAction,
      actions,
      disabledReasons,
    };
  }

  appendTakeTokenActions(state, actions);
  appendReserveActions(state, player, actions);
  appendBuyActions(state, player, actions);

  if (actions.length === 0) {
    disabledReasons.push('no legal actions available');
  }

  return {
    playerIndex,
    pendingAction: state.pendingAction,
    actions,
    disabledReasons,
  };
}
