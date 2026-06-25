import { broadcastGameState } from './service.js';

/**
 * Cross-feature bridge for game state synchronization.
 *
 * Allows the splendor module to notify the online module when a game state
 * changes, without creating a circular dependency. The online module owns
 * the broadcast logic; this file is the interface splendor imports.
 */

/**
 * Broadcasts the latest game state to all online room subscribers.
 *
 * Called after a splendor action is submitted. If the session is linked to
 * an online room, emits a game_state_updated event to all room subscribers.
 * No-op if the session is not an online game.
 */
export async function notifyGameStateChanged(sessionId: string): Promise<void> {
  await broadcastGameState(sessionId);
}
