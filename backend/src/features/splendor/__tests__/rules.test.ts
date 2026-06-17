import assert from 'node:assert/strict';
import { test } from 'node:test';
import { applySplendorAction, generateSplendorLegalActions } from '../rules.js';
import { createInitialSplendorState } from '../state.js';
import type { SplendorGameState } from '../types.js';

const createTwoPlayerState = (): SplendorGameState =>
  createInitialSplendorState({
    playerCount: 2,
    players: [{ name: 'A' }, { name: 'B' }],
  });

test('generates legal actions for an active session', () => {
  const state = createTwoPlayerState();
  const result = generateSplendorLegalActions(state);

  assert.equal(result.playerIndex, 0);
  assert.equal(result.pendingAction, null);
  assert.ok(result.actions.some((item) => item.action.type === 'take_tokens'));
  assert.ok(result.actions.some((item) => item.action.type === 'reserve_card'));
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

test('enters choose noble pending action when multiple nobles are eligible', () => {
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

  assert.equal(afterBuy.pendingAction?.type, 'choose_noble');
  assert.deepEqual(afterBuy.pendingAction?.nobleIds, ['noble-001', 'noble-002']);
  assert.equal(afterBuy.currentPlayerIndex, 0);

  const legalActions = generateSplendorLegalActions(afterBuy);
  assert.equal(legalActions.actions.length, 2);
  assert.ok(legalActions.actions.every((item) => item.action.type === 'choose_noble'));

  const afterChoose = applySplendorAction(afterBuy, 0, {
    type: 'choose_noble',
    nobleId: 'noble-001',
  });

  assert.equal(afterChoose.pendingAction, null);
  assert.equal(afterChoose.currentPlayerIndex, 1);
  assert.equal(afterChoose.players[0].nobles.includes('noble-001'), true);
});
