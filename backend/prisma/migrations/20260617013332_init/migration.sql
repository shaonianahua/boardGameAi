-- CreateTable
CREATE TABLE "GameSession" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "gameType" TEXT NOT NULL,
    "title" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL
);

-- CreateTable
CREATE TABLE "GameTurn" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "sessionId" TEXT NOT NULL,
    "turnIndex" INTEGER NOT NULL,
    "playerIndex" INTEGER NOT NULL,
    "stateJson" TEXT NOT NULL,
    "legalActionsJson" TEXT NOT NULL,
    "chosenActionJson" TEXT,
    "adviceJson" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "GameTurn_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "GameSession" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateIndex
CREATE INDEX "GameSession_gameType_idx" ON "GameSession"("gameType");

-- CreateIndex
CREATE INDEX "GameTurn_sessionId_turnIndex_idx" ON "GameTurn"("sessionId", "turnIndex");

-- CreateIndex
CREATE INDEX "GameTurn_sessionId_playerIndex_idx" ON "GameTurn"("sessionId", "playerIndex");
