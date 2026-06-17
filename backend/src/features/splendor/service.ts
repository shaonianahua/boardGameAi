import type { GameAction, GamePlayer, GameSession, Prisma } from '@prisma/client';
import { prisma } from '../../db/prisma.js';
import { actionType, applySplendorAction, generateSplendorLegalActions } from './rules.js';
import { createInitialSplendorState, parseState, stringifyState } from './state.js';
import type {
  CreateSplendorSessionInput,
  SplendorGameState,
  SplendorLegalActionsResult,
  SubmitSplendorActionInput,
} from './types.js';

export interface SplendorSessionResponse {
  session: PublicSession;
  players: GamePlayer[];
  state: SplendorGameState;
}

export interface PublicSession {
  id: string;
  gameType: string;
  title: string | null;
  status: string;
  playerCount: number;
  currentTurnIndex: number;
  currentPlayerIndex: number;
  winnerPlayerIndex: number | null;
  createdAt: Date;
  updatedAt: Date;
  finishedAt: Date | null;
}

export interface PublicActionRecord {
  id: string;
  sessionId: string;
  turnIndex: number;
  playerIndex: number;
  actorType: string;
  actionType: string;
  action: unknown;
  stateBefore: SplendorGameState;
  stateAfter: SplendorGameState;
  createdAt: Date;
}

type GameSessionWithPlayers = Prisma.GameSessionGetPayload<{
  include: {
    players: true;
  };
}>;

function safeJson(value: unknown): string {
  return JSON.stringify(value);
}

function publicSession(session: GameSession): PublicSession {
  return {
    id: session.id,
    gameType: session.gameType,
    title: session.title,
    status: session.status,
    playerCount: session.playerCount,
    currentTurnIndex: session.currentTurnIndex,
    currentPlayerIndex: session.currentPlayerIndex,
    winnerPlayerIndex: session.winnerPlayerIndex,
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
    finishedAt: session.finishedAt,
  };
}

function publicAction(action: GameAction): PublicActionRecord {
  return {
    id: action.id,
    sessionId: action.sessionId,
    turnIndex: action.turnIndex,
    playerIndex: action.playerIndex,
    actorType: action.actorType,
    actionType: action.actionType,
    action: JSON.parse(action.actionJson) as unknown,
    stateBefore: parseState(action.stateBeforeJson),
    stateAfter: parseState(action.stateAfterJson),
    createdAt: action.createdAt,
  };
}

function publicSessionResponse(
  session: GameSessionWithPlayers,
  state: SplendorGameState,
): SplendorSessionResponse {
  return {
    session: publicSession(session),
    players: session.players,
    state,
  };
}

export async function createSplendorSession(
  input: CreateSplendorSessionInput,
): Promise<SplendorSessionResponse> {
  const state = createInitialSplendorState(input);

  const session = await prisma.gameSession.create({
    data: {
      gameType: 'splendor',
      title: input.title,
      status: state.status,
      playerCount: state.playerCount,
      currentTurnIndex: state.currentTurnIndex,
      currentPlayerIndex: state.currentPlayerIndex,
      winnerPlayerIndex: state.winnerPlayerIndex,
      stateJson: stringifyState(state),
      players: {
        create: state.players.map((player) => ({
          seatIndex: player.seatIndex,
          name: player.name,
          playerType: player.type,
          botLevel: player.botLevel,
        })),
      },
    },
    include: {
      players: {
        orderBy: { seatIndex: 'asc' },
      },
    },
  });

  return publicSessionResponse(session, state);
}

export async function getSplendorSession(sessionId: string): Promise<SplendorSessionResponse> {
  const session = await prisma.gameSession.findUnique({
    where: { id: sessionId },
    include: {
      players: {
        orderBy: { seatIndex: 'asc' },
      },
    },
  });

  if (!session || session.gameType !== 'splendor') {
    throw new Error('session not found');
  }

  return publicSessionResponse(session, parseState(session.stateJson));
}

export async function submitSplendorAction(
  sessionId: string,
  input: SubmitSplendorActionInput,
): Promise<{ session: PublicSession; actionRecord: PublicActionRecord; state: SplendorGameState }> {
  const existing = await getSplendorSession(sessionId);
  const beforeState = existing.state;
  const afterState = applySplendorAction(beforeState, input.playerIndex, input.action);
  const actorType = input.actorType ?? existing.players[input.playerIndex]?.playerType ?? 'human';

  const [actionRecord, session] = await prisma.$transaction(async (tx) => {
    const createdAction = await tx.gameAction.create({
      data: {
        sessionId,
        turnIndex: beforeState.currentTurnIndex,
        playerIndex: input.playerIndex,
        actorType,
        actionType: actionType(input.action),
        actionJson: safeJson(input.action),
        stateBeforeJson: stringifyState(beforeState),
        stateAfterJson: stringifyState(afterState),
      },
    });

    const updatedSession = await tx.gameSession.update({
      where: { id: sessionId },
      data: {
        status: afterState.status,
        currentTurnIndex: afterState.currentTurnIndex,
        currentPlayerIndex: afterState.currentPlayerIndex,
        winnerPlayerIndex: afterState.winnerPlayerIndex,
        stateJson: stringifyState(afterState),
        finishedAt: afterState.status === 'finished' ? new Date() : null,
      },
    });

    return [createdAction, updatedSession] as const;
  });

  return {
    session: publicSession(session),
    actionRecord: publicAction(actionRecord),
    state: afterState,
  };
}

export async function listSplendorActions(sessionId: string): Promise<PublicActionRecord[]> {
  const actions = await prisma.gameAction.findMany({
    where: { sessionId },
    orderBy: [{ turnIndex: 'asc' }, { createdAt: 'asc' }],
  });
  return actions.map(publicAction);
}

export async function getSplendorLegalActions(
  sessionId: string,
): Promise<SplendorLegalActionsResult> {
  const existing = await getSplendorSession(sessionId);
  return generateSplendorLegalActions(existing.state);
}
