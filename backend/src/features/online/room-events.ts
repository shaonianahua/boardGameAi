import type { WebSocket } from '@fastify/websocket';
import type { OnlineRoomEvent } from './types.js';

const roomSubscribers = new Map<string, Set<WebSocket>>();

/** Adds a WebSocket connection to a room subscription set. */
export function subscribeOnlineRoom(roomId: string, socket: WebSocket): void {
  const subscribers = roomSubscribers.get(roomId) ?? new Set<WebSocket>();
  subscribers.add(socket);
  roomSubscribers.set(roomId, subscribers);
}

/** Removes a WebSocket connection from a room subscription set. */
export function unsubscribeOnlineRoom(roomId: string, socket: WebSocket): void {
  const subscribers = roomSubscribers.get(roomId);
  if (!subscribers) {
    return;
  }

  subscribers.delete(socket);
  if (subscribers.size === 0) {
    roomSubscribers.delete(roomId);
  }
}

/** Broadcasts a room event to every active WebSocket subscriber. */
export function broadcastOnlineRoomEvent(roomId: string, event: OnlineRoomEvent): void {
  const subscribers = roomSubscribers.get(roomId);
  if (!subscribers || subscribers.size === 0) {
    return;
  }

  const payload = JSON.stringify(event);
  for (const socket of subscribers) {
    if (socket.readyState === socket.OPEN) {
      socket.send(payload);
    }
  }
}
