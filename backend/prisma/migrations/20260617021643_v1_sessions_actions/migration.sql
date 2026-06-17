/*
  Warnings:

  - You are about to drop the `GameTurn` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `playerCount` to the `GameSession` table without a default value. This is not possible if the table is not empty.
  - Added the required column `stateJson` to the `GameSession` table without a default value. This is not possible if the table is not empty.

*/
-- DropIndex
DROP INDEX "GameTurn_sessionId_playerIndex_idx";

-- DropIndex
DROP INDEX "GameTurn_sessionId_turnIndex_idx";

-- DropTable
PRAGMA foreign_keys=off;
DROP TABLE "GameTurn";
PRAGMA foreign_keys=on;

-- CreateTable
CREATE TABLE "GamePlayer" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "sessionId" TEXT NOT NULL,
    "seatIndex" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "playerType" TEXT NOT NULL,
    "botLevel" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "GamePlayer_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "GameSession" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "GameAction" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "sessionId" TEXT NOT NULL,
    "turnIndex" INTEGER NOT NULL,
    "playerIndex" INTEGER NOT NULL,
    "actorType" TEXT NOT NULL,
    "actionType" TEXT NOT NULL,
    "actionJson" TEXT NOT NULL,
    "stateBeforeJson" TEXT NOT NULL,
    "stateAfterJson" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "GameAction_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "GameSession" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "AiDecision" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "sessionId" TEXT NOT NULL,
    "actionId" TEXT,
    "playerIndex" INTEGER NOT NULL,
    "provider" TEXT NOT NULL,
    "model" TEXT,
    "inputJson" TEXT NOT NULL,
    "outputJson" TEXT NOT NULL,
    "selectedActionJson" TEXT NOT NULL,
    "tokenUsageJson" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "AiDecision_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "GameSession" ("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "AiDecision_actionId_fkey" FOREIGN KEY ("actionId") REFERENCES "GameAction" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- RedefineTables
PRAGMA defer_foreign_keys=ON;
PRAGMA foreign_keys=OFF;
CREATE TABLE "new_GameSession" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "gameType" TEXT NOT NULL,
    "title" TEXT,
    "status" TEXT NOT NULL DEFAULT 'active',
    "playerCount" INTEGER NOT NULL,
    "currentTurnIndex" INTEGER NOT NULL DEFAULT 0,
    "currentPlayerIndex" INTEGER NOT NULL DEFAULT 0,
    "winnerPlayerIndex" INTEGER,
    "stateJson" TEXT NOT NULL,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    "finishedAt" DATETIME
);
INSERT INTO "new_GameSession" ("createdAt", "gameType", "id", "title", "updatedAt") SELECT "createdAt", "gameType", "id", "title", "updatedAt" FROM "GameSession";
DROP TABLE "GameSession";
ALTER TABLE "new_GameSession" RENAME TO "GameSession";
CREATE INDEX "GameSession_gameType_idx" ON "GameSession"("gameType");
CREATE INDEX "GameSession_status_idx" ON "GameSession"("status");
CREATE INDEX "GameSession_updatedAt_idx" ON "GameSession"("updatedAt");
PRAGMA foreign_keys=ON;
PRAGMA defer_foreign_keys=OFF;

-- CreateIndex
CREATE INDEX "GamePlayer_sessionId_idx" ON "GamePlayer"("sessionId");

-- CreateIndex
CREATE UNIQUE INDEX "GamePlayer_sessionId_seatIndex_key" ON "GamePlayer"("sessionId", "seatIndex");

-- CreateIndex
CREATE INDEX "GameAction_sessionId_turnIndex_idx" ON "GameAction"("sessionId", "turnIndex");

-- CreateIndex
CREATE INDEX "GameAction_sessionId_playerIndex_idx" ON "GameAction"("sessionId", "playerIndex");

-- CreateIndex
CREATE INDEX "GameAction_actionType_idx" ON "GameAction"("actionType");

-- CreateIndex
CREATE UNIQUE INDEX "AiDecision_actionId_key" ON "AiDecision"("actionId");

-- CreateIndex
CREATE INDEX "AiDecision_sessionId_idx" ON "AiDecision"("sessionId");

-- CreateIndex
CREATE INDEX "AiDecision_playerIndex_idx" ON "AiDecision"("playerIndex");
