import type { OnlineRoom, OnlineRoomSeat } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { prisma } from '../../db/prisma.js';
import { broadcastOnlineRoomEvent } from './room-events.js';
import type {
  CreateOnlineRoomInput,
  JoinOnlineRoomInput,
  OnlineSeatControlType,
  PublicOnlineRoom,
  PublicOnlineRoomSeat,
} from './types.js';

const maxSeatCount = 4;
const roomCodeLength = 6;

type OnlineRoomWithSeats = OnlineRoom & {
  seats: OnlineRoomSeat[];
};

/** Creates a new online room and puts the creator into seat 0. */
export async function createOnlineRoom(input: CreateOnlineRoomInput): Promise<PublicOnlineRoom> {
  const hostName = normalizePlayerName(input.hostName);
  const clientId = input.clientId?.trim() || randomUUID();
  const roomCode = await generateUniqueRoomCode();

  const room = await prisma.onlineRoom.create({
    data: {
      roomCode,
      gameType: input.gameType ?? 'splendor',
      hostSeatIndex: 0,
      seats: {
        create: {
          seatIndex: 0,
          playerName: hostName,
          clientId,
          controlType: 'human',
          ready: false,
          connected: true,
        },
      },
    },
    include: {
      seats: {
        orderBy: { seatIndex: 'asc' },
      },
    },
  });

  return publicRoom(room);
}

/** Returns an online room snapshot by room code. */
export async function getOnlineRoomByCode(roomCode: string): Promise<PublicOnlineRoom> {
  const room = await findRoomByCode(roomCode);
  return publicRoom(room);
}

/** Joins an existing waiting room and broadcasts the updated room snapshot. */
export async function joinOnlineRoom(input: JoinOnlineRoomInput): Promise<PublicOnlineRoom> {
  const normalizedRoomCode = normalizeRoomCode(input.roomCode);
  const playerName = normalizePlayerName(input.playerName);
  const clientId = input.clientId?.trim() || randomUUID();
  const controlType = normalizeControlType(input.controlType);

  const room = await findRoomByCode(normalizedRoomCode);
  if (room.status !== 'waiting') {
    throw new Error('room is not waiting');
  }

  const existingSeat = room.seats.find((seat) => seat.clientId === clientId);
  if (existingSeat) {
    const updatedRoom = await prisma.onlineRoom.update({
      where: { id: room.id },
      data: {
        seats: {
          update: {
            where: { id: existingSeat.id },
            data: {
              playerName,
              controlType,
              connected: true,
            },
          },
        },
      },
      include: {
        seats: {
          orderBy: { seatIndex: 'asc' },
        },
      },
    });
    const snapshot = publicRoom(updatedRoom);
    broadcastOnlineRoomEvent(room.id, { type: 'room_updated', room: snapshot });
    return snapshot;
  }

  const seatIndex = firstAvailableSeatIndex(room.seats);
  if (seatIndex == null) {
    throw new Error('room is full');
  }

  const updatedRoom = await prisma.onlineRoom.update({
    where: { id: room.id },
    data: {
      seats: {
        create: {
          seatIndex,
          playerName,
          clientId,
          controlType,
          ready: false,
          connected: true,
        },
      },
    },
    include: {
      seats: {
        orderBy: { seatIndex: 'asc' },
      },
    },
  });
  const snapshot = publicRoom(updatedRoom);
  broadcastOnlineRoomEvent(room.id, { type: 'room_updated', room: snapshot });
  return snapshot;
}

/** Converts a Prisma room with seats into the public API shape. */
export function publicRoom(room: OnlineRoomWithSeats): PublicOnlineRoom {
  return {
    id: room.id,
    roomCode: room.roomCode,
    gameType: room.gameType,
    status: room.status as PublicOnlineRoom['status'],
    hostSeatIndex: room.hostSeatIndex,
    sessionId: room.sessionId,
    seats: room.seats
      .slice()
      .sort((left, right) => left.seatIndex - right.seatIndex)
      .map(publicSeat),
    createdAt: room.createdAt,
    updatedAt: room.updatedAt,
  };
}

/** Converts a Prisma room seat into the public API shape. */
function publicSeat(seat: OnlineRoomSeat): PublicOnlineRoomSeat {
  return {
    id: seat.id,
    roomId: seat.roomId,
    seatIndex: seat.seatIndex,
    playerName: seat.playerName,
    clientId: seat.clientId,
    controlType: seat.controlType as OnlineSeatControlType,
    ready: seat.ready,
    connected: seat.connected,
    createdAt: seat.createdAt,
    updatedAt: seat.updatedAt,
  };
}

/** Finds a room by room code and includes seats ordered by seat index. */
async function findRoomByCode(roomCode: string): Promise<OnlineRoomWithSeats> {
  const room = await prisma.onlineRoom.findUnique({
    where: { roomCode: normalizeRoomCode(roomCode) },
    include: {
      seats: {
        orderBy: { seatIndex: 'asc' },
      },
    },
  });
  if (!room) {
    throw new Error('room not found');
  }
  return room;
}

/** Generates a unique short room code for joining from another device. */
async function generateUniqueRoomCode(): Promise<string> {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    const roomCode = randomRoomCode();
    const existingRoom = await prisma.onlineRoom.findUnique({ where: { roomCode } });
    if (!existingRoom) {
      return roomCode;
    }
  }
  throw new Error('failed to generate room code');
}

/** Creates a random uppercase alphanumeric room code. */
function randomRoomCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let value = '';
  for (let index = 0; index < roomCodeLength; index += 1) {
    value += chars[Math.floor(Math.random() * chars.length)];
  }
  return value;
}

/** Normalizes user-entered room code text for lookup. */
function normalizeRoomCode(roomCode: string): string {
  return roomCode.trim().toUpperCase();
}

/** Normalizes player display name and rejects blank names. */
function normalizePlayerName(playerName: string): string {
  const normalizedName = playerName.trim();
  if (!normalizedName) {
    throw new Error('playerName is required');
  }
  return normalizedName;
}

/** Normalizes seat control type and defaults to human. */
function normalizeControlType(value?: OnlineSeatControlType): OnlineSeatControlType {
  if (value === 'local_bot' || value === 'ai_player') {
    return value;
  }
  return 'human';
}

/** Finds the smallest available seat index in a room. */
function firstAvailableSeatIndex(seats: OnlineRoomSeat[]): number | null {
  const usedSeatIndexes = new Set(seats.map((seat) => seat.seatIndex));
  for (let seatIndex = 0; seatIndex < maxSeatCount; seatIndex += 1) {
    if (!usedSeatIndexes.has(seatIndex)) {
      return seatIndex;
    }
  }
  return null;
}
