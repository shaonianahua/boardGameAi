-- CreateTable
CREATE TABLE "OnlineRoom" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "roomCode" TEXT NOT NULL,
    "gameType" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'waiting',
    "hostSeatIndex" INTEGER,
    "sessionId" TEXT,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "OnlineRoom_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "GameSession" ("id") ON DELETE SET NULL ON UPDATE CASCADE
);

-- CreateTable
CREATE TABLE "OnlineRoomSeat" (
    "id" TEXT NOT NULL PRIMARY KEY,
    "roomId" TEXT NOT NULL,
    "seatIndex" INTEGER NOT NULL,
    "playerName" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "controlType" TEXT NOT NULL,
    "ready" BOOLEAN NOT NULL DEFAULT false,
    "connected" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" DATETIME NOT NULL,
    CONSTRAINT "OnlineRoomSeat_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "OnlineRoom" ("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- CreateIndex
CREATE UNIQUE INDEX "OnlineRoom_roomCode_key" ON "OnlineRoom"("roomCode");

-- CreateIndex
CREATE INDEX "OnlineRoom_gameType_idx" ON "OnlineRoom"("gameType");

-- CreateIndex
CREATE INDEX "OnlineRoom_status_idx" ON "OnlineRoom"("status");

-- CreateIndex
CREATE INDEX "OnlineRoom_updatedAt_idx" ON "OnlineRoom"("updatedAt");

-- CreateIndex
CREATE INDEX "OnlineRoomSeat_roomId_idx" ON "OnlineRoomSeat"("roomId");

-- CreateIndex
CREATE UNIQUE INDEX "OnlineRoomSeat_roomId_seatIndex_key" ON "OnlineRoomSeat"("roomId", "seatIndex");

-- CreateIndex
CREATE UNIQUE INDEX "OnlineRoomSeat_roomId_clientId_key" ON "OnlineRoomSeat"("roomId", "clientId");
