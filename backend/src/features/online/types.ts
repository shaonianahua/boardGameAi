/** Online room lifecycle status used before and during network games. */
export type OnlineRoomStatus = 'waiting' | 'playing' | 'finished' | 'closed';

/** Seat controller type shown in online lobby and later mapped to game players. */
export type OnlineSeatControlType = 'human' | 'local_bot' | 'ai_player';

/** Request body for creating an online room and occupying the host seat. */
export interface CreateOnlineRoomInput {
  gameType?: string;
  hostName: string;
  clientId?: string;
}

/** Request body for joining an existing online room by room code. */
export interface JoinOnlineRoomInput {
  roomCode: string;
  playerName: string;
  clientId?: string;
  controlType?: OnlineSeatControlType;
}

/** Public seat shape returned to clients and broadcast over room events. */
export interface PublicOnlineRoomSeat {
  id: string;
  roomId: string;
  seatIndex: number;
  playerName: string;
  clientId: string;
  controlType: OnlineSeatControlType;
  ready: boolean;
  connected: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/** Public room snapshot returned by REST APIs and WebSocket room events. */
export interface PublicOnlineRoom {
  id: string;
  roomCode: string;
  gameType: string;
  status: OnlineRoomStatus;
  hostSeatIndex: number | null;
  sessionId: string | null;
  seats: PublicOnlineRoomSeat[];
  createdAt: Date;
  updatedAt: Date;
}

/** WebSocket event payloads emitted by the online room module. */
export type OnlineRoomEvent =
  | {
      type: 'room_snapshot';
      room: PublicOnlineRoom;
    }
  | {
      type: 'room_updated';
      room: PublicOnlineRoom;
    };
