import type { FastifyInstance } from 'fastify';
import {
  createOnlineRoom,
  getOnlineRoomByCode,
  joinOnlineRoom,
  leaveOnlineRoom,
  startOnlineGame,
} from './service.js';
import {
  subscribeOnlineRoom,
  unsubscribeOnlineRoom,
} from './room-events.js';
import type {
  CreateOnlineRoomInput,
  JoinOnlineRoomInput,
  LeaveOnlineRoomInput,
  StartOnlineGameInput,
} from './types.js';

/** Converts any thrown value into a readable API error message. */
function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'unknown error';
}

/** Converts an error message into a stable uppercase error code. */
function errorCode(error: unknown): string {
  const message = errorMessage(error);
  return (
    message
      .replace(/[^a-zA-Z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .toUpperCase() || 'UNKNOWN_ERROR'
  );
}

/** Builds the shared error response shape used by online room APIs. */
function errorResponse(error: unknown): { error: { code: string; message: string } } {
  return {
    error: {
      code: errorCode(error),
      message: errorMessage(error),
    },
  };
}

/** Registers online room REST APIs and the WebSocket room event stream. */
export async function registerOnlineRoutes(app: FastifyInstance): Promise<void> {
  app.post('/api/online/rooms', async (request, reply) => {
    try {
      return await createOnlineRoom(request.body as CreateOnlineRoomInput);
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.post('/api/online/rooms/join', async (request, reply) => {
    try {
      return await joinOnlineRoom(request.body as JoinOnlineRoomInput);
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.post('/api/online/rooms/leave', async (request, reply) => {
    try {
      return await leaveOnlineRoom(request.body as LeaveOnlineRoomInput);
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.post('/api/online/rooms/:roomCode/start', async (request, reply) => {
    try {
      const params = request.params as { roomCode: string };
      const body = request.body as { clientId: string };
      return await startOnlineGame({
        roomCode: params.roomCode,
        clientId: body.clientId,
      });
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.get('/api/online/rooms/:roomCode', async (request, reply) => {
    try {
      const params = request.params as { roomCode: string };
      return await getOnlineRoomByCode(params.roomCode);
    } catch (error) {
      return reply.status(404).send(errorResponse(error));
    }
  });

  app.get('/api/online/rooms/:roomCode/events', { websocket: true }, async (socket, request) => {
    const params = request.params as { roomCode: string };
    // clientId lets us release this player's seat when the socket drops
    // (closed app / lost network) without an explicit leave request.
    const query = request.query as { clientId?: string };
    const clientId = query.clientId?.trim();

    try {
      const room = await getOnlineRoomByCode(params.roomCode);
      subscribeOnlineRoom(room.id, socket);
      socket.send(JSON.stringify({ type: 'room_snapshot', room }));
      socket.on('close', () => {
        unsubscribeOnlineRoom(room.id, socket);
        if (clientId) {
          handleDisconnect(params.roomCode, clientId, app).catch((error) => {
            app.log.warn({ err: error }, 'disconnect handler failed');
          });
        }
      });
    } catch (error) {
      socket.send(JSON.stringify(errorResponse(error)));
      socket.close();
    }
  });
}

/**
 * Handles player disconnect based on room status.
 *
 * - If room is 'waiting': delete the seat (existing leaveOnlineRoom behavior)
 * - If room is 'playing': change seat controlType to 'local_bot' so the backend
 *   drives that seat's turns going forward, then broadcast the takeover
 */
async function handleDisconnect(
  roomCode: string,
  clientId: string,
  app: FastifyInstance,
): Promise<void> {
  const room = await getOnlineRoomByCode(roomCode);

  if (room.status === 'waiting') {
    // Room not started yet; delete the seat as before
    await leaveOnlineRoom({ roomCode, clientId });
    return;
  }

  if (room.status === 'playing') {
    // Game in progress; take over with local bot instead of removing seat
    const seat = room.seats.find((s) => s.clientId === clientId);
    if (!seat) {
      return; // Seat already gone or wrong clientId
    }

    const { prisma } = await import('../../db/prisma.js');
    await prisma.onlineRoomSeat.update({
      where: { id: seat.id },
      data: { controlType: 'local_bot', connected: false },
    });

    const updatedRoom = await getOnlineRoomByCode(roomCode);
    const { broadcastOnlineRoomEvent } = await import('./room-events.js');
    broadcastOnlineRoomEvent(updatedRoom.id, {
      type: 'room_updated',
      room: updatedRoom,
    });

    // If it's now this bot's turn, drive it immediately
    if (room.sessionId) {
      const { broadcastGameState } = await import('./service.js');
      const { getSplendorSession } = await import('../splendor/service.js');
      const session = await getSplendorSession(room.sessionId);
      const currentPlayer = session.state.players[session.state.currentPlayerIndex];
      if (currentPlayer && currentPlayer.seatIndex === seat.seatIndex) {
        // It's the disconnected player's turn; drive one bot action
        const { driveBotsUntilHumanTurn } = await import('./service.js');
        await driveBotsUntilHumanTurn(room.sessionId);
      }
    }
  }
}
