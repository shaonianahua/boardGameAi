import assert from 'node:assert/strict';
import { test } from 'node:test';
import { applySplendorAction, generateSplendorLegalActions } from '../rules.js';
import { automaticSplendorActions } from '../service.js';
import { createInitialSplendorState } from '../state.js';
import type { SplendorGameState } from '../types.js';

const createTwoPlayerState = (): SplendorGameState =>
  createInitialSplendorState({
    playerCount: 2,
    players: [{ name: 'A' }, { name: 'B' }],
  });

const createFourPlayerState = (): SplendorGameState =>
  createInitialSplendorState({
    playerCount: 4,
    players: [{ name: 'A' }, { name: 'B' }, { name: 'C' }, { name: 'D' }],
  });

test('generates legal actions for an active session', () => {
  const state = createTwoPlayerState();
  const result = generateSplendorLegalActions(state);

  assert.equal(result.playerIndex, 0);
  assert.equal(result.pendingAction, null);
  assert.ok(result.actions.some((item) => item.action.type === 'take_tokens'));
  assert.ok(result.actions.some((item) => item.action.type === 'reserve_card'));
});

test('allows taking two different tokens when only two gem colors remain', () => {
  const state: SplendorGameState = {
    ...createTwoPlayerState(),
    tokenPool: {
      white: 2,
      blue: 3,
      green: 0,
      red: 0,
      black: 0,
      gold: 5,
    },
  };

  const result = generateSplendorLegalActions(state);
  assert.ok(
    result.actions.some((item) => {
      if (item.action.type !== 'take_tokens') return false;
      return item.action.tokens.white === 1 && item.action.tokens.blue === 1;
    }),
  );

  const afterTake = applySplendorAction(state, 0, {
    type: 'take_tokens',
    tokens: { white: 1, blue: 1 },
  });

  assert.equal(afterTake.players[0].tokens.white, 1);
  assert.equal(afterTake.players[0].tokens.blue, 1);
  assert.equal(afterTake.pendingAction, null);
  assert.equal(afterTake.currentPlayerIndex, 1);
});

test('allows taking two different tokens with six held tokens when only two gem colors remain', () => {
  const state = createTwoPlayerState();
  const sixTokenState: SplendorGameState = {
    ...state,
    tokenPool: {
      white: 2,
      blue: 3,
      green: 0,
      red: 0,
      black: 0,
      gold: 5,
    },
    players: state.players.map((player, index) =>
      index === 0
        ? {
            ...player,
            tokens: {
              white: 1,
              blue: 1,
              green: 1,
              red: 1,
              black: 1,
              gold: 1,
            },
          }
        : player,
    ),
  };

  const result = generateSplendorLegalActions(sixTokenState);
  assert.ok(
    result.actions.some((item) => {
      if (item.action.type !== 'take_tokens') return false;
      return item.action.tokens.white === 1 && item.action.tokens.blue === 1;
    }),
  );

  const afterTake = applySplendorAction(sixTokenState, 0, {
    type: 'take_tokens',
    tokens: { white: 1, blue: 1 },
  });

  assert.equal(afterTake.players[0].tokens.white, 2);
  assert.equal(afterTake.players[0].tokens.blue, 2);
  assert.equal(afterTake.pendingAction, null);
  assert.equal(afterTake.currentPlayerIndex, 1);
});

test('does not allow taking two different tokens when at least three gem colors remain', () => {
  const state = createTwoPlayerState();

  assert.throws(
    () =>
      applySplendorAction(state, 0, {
        type: 'take_tokens',
        tokens: { white: 1, blue: 1 },
      }),
    /taking 2 tokens requires one color/,
  );
});

test('enters discard pending action and resolves it before advancing turn', () => {
  const state = createTwoPlayerState();
  const overloadedState: SplendorGameState = {
    ...state,
    tokenPool: {
      white: 4,
      blue: 4,
      green: 4,
      red: 4,
      black: 4,
      gold: 5,
    },
    players: state.players.map((player, index) =>
      index === 0
        ? {
            ...player,
            tokens: {
              white: 3,
              blue: 3,
              green: 3,
              red: 1,
              black: 0,
              gold: 0,
            },
          }
        : player,
    ),
  };

  const afterTake = applySplendorAction(overloadedState, 0, {
    type: 'take_tokens',
    tokens: { white: 1, blue: 1, green: 1 },
  });

  assert.equal(afterTake.pendingAction?.type, 'discard_tokens');
  assert.equal(afterTake.currentPlayerIndex, 0);

  const legalActions = generateSplendorLegalActions(afterTake);
  assert.ok(legalActions.actions.every((item) => item.action.type === 'discard_tokens'));

  const afterDiscard = applySplendorAction(afterTake, 0, {
    type: 'discard_tokens',
    tokens: { white: 1, blue: 1, green: 1 },
  });

  assert.equal(afterDiscard.pendingAction, null);
  assert.equal(afterDiscard.currentPlayerIndex, 1);
});

test('allows taking tokens at ten held tokens before discarding back to ten', () => {
  const state = createTwoPlayerState();
  const fullHandState: SplendorGameState = {
    ...state,
    tokenPool: {
      white: 4,
      blue: 4,
      green: 4,
      red: 4,
      black: 4,
      gold: 5,
    },
    players: state.players.map((player, index) =>
      index === 0
        ? {
            ...player,
            tokens: {
              white: 2,
              blue: 2,
              green: 2,
              red: 2,
              black: 2,
              gold: 0,
            },
          }
        : player,
    ),
  };

  const afterTake = applySplendorAction(fullHandState, 0, {
    type: 'take_tokens',
    tokens: { white: 1, blue: 1, green: 1 },
  });

  assert.equal(afterTake.pendingAction?.type, 'discard_tokens');
  assert.equal(afterTake.pendingAction?.tokenCount, 13);
  assert.equal(afterTake.currentPlayerIndex, 0);

  const afterDiscard = applySplendorAction(afterTake, 0, {
    type: 'discard_tokens',
    tokens: { white: 1, blue: 1, green: 1 },
  });

  assert.equal(afterDiscard.pendingAction, null);
  assert.equal(afterDiscard.currentPlayerIndex, 1);
});

test('automatically awards one noble at turn end when multiple nobles are eligible', () => {
  const state = createTwoPlayerState();
  const nobleState: SplendorGameState = {
    ...state,
    nobles: ['noble-001', 'noble-002'],
    markets: {
      ...state.markets,
      level1: ['dev-1-033'],
    },
    decks: {
      ...state.decks,
      level1: [],
    },
    players: state.players.map((player, index) =>
      index === 0
        ? {
            ...player,
            bonuses: {
              white: 3,
              blue: 3,
              green: 3,
              red: 3,
              black: 2,
            },
          }
        : player,
    ),
  };

  const afterBuy = applySplendorAction(nobleState, 0, {
    type: 'buy_card',
    source: 'market',
    cardId: 'dev-1-033',
  });

  assert.equal(afterBuy.pendingAction, null);
  assert.equal(afterBuy.currentPlayerIndex, 1);
  assert.deepEqual(afterBuy.players[0].nobles, ['noble-001']);
  assert.equal(afterBuy.nobles.includes('noble-001'), false);
  assert.equal(afterBuy.nobles.includes('noble-002'), true);
  assert.equal(afterBuy.players[0].score, 3);

  const legalActions = generateSplendorLegalActions(afterBuy);
  assert.equal(legalActions.pendingAction, null);
  assert.ok(legalActions.actions.every((item) => item.action.type !== 'choose_noble'));

  const automaticActions = automaticSplendorActions(nobleState, afterBuy);
  assert.equal(automaticActions.length, 1);
  assert.equal(automaticActions[0].playerIndex, 0);
  assert.equal(automaticActions[0].actorType, 'system');
  assert.deepEqual(automaticActions[0].action, {
    type: 'noble_visit',
    nobleId: 'noble-001',
  });
});

test('finishes the game only after remaining players complete the final round', () => {
  const state = createFourPlayerState();
  const scoringState: SplendorGameState = {
    ...state,
    currentPlayerIndex: 1,
    players: state.players.map((player, index) =>
      index === 1
        ? {
            ...player,
            score: 15,
          }
        : player,
    ),
  };

  const afterPlayerTwo = applySplendorAction(scoringState, 1, {
    type: 'take_tokens',
    tokens: { white: 1, blue: 1, green: 1 },
  });

  assert.equal(afterPlayerTwo.finalRound.triggered, true);
  assert.equal(afterPlayerTwo.finalRound.triggeredByPlayerIndex, 1);
  assert.equal(afterPlayerTwo.finalRound.roundEndPlayerIndex, 3);
  assert.equal(afterPlayerTwo.status, 'active');
  assert.equal(afterPlayerTwo.currentPlayerIndex, 2);

  const afterPlayerThree = applySplendorAction(afterPlayerTwo, 2, {
    type: 'take_tokens',
    tokens: { white: 1, blue: 1, green: 1 },
  });

  assert.equal(afterPlayerThree.status, 'active');
  assert.equal(afterPlayerThree.currentPlayerIndex, 3);

  const afterPlayerFour = applySplendorAction(afterPlayerThree, 3, {
    type: 'take_tokens',
    tokens: { white: 1, blue: 1, green: 1 },
  });

  assert.equal(afterPlayerFour.status, 'finished');
  assert.equal(afterPlayerFour.winnerPlayerIndex, 1);
  assert.equal(afterPlayerFour.currentPlayerIndex, 3);
});
