import type { FastifyInstance } from 'fastify';
import {
  createOnlineRoom,
  getOnlineRoomByCode,
  joinOnlineRoom,
} from './service.js';
import {
  subscribeOnlineRoom,
  unsubscribeOnlineRoom,
} from './room-events.js';
import type { CreateOnlineRoomInput, JoinOnlineRoomInput } from './types.js';

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

    try {
      const room = await getOnlineRoomByCode(params.roomCode);
      subscribeOnlineRoom(room.id, socket);
      socket.send(JSON.stringify({ type: 'room_snapshot', room }));
      socket.on('close', () => {
        unsubscribeOnlineRoom(room.id, socket);
      });
    } catch (error) {
      socket.send(JSON.stringify(errorResponse(error)));
      socket.close();
    }
  });
}
