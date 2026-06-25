# 璀璨宝石联机对局设计文档（V4 第二阶段）

## 概述

联机对局是 V4 第二阶段功能，在已有的在线房间大厅基础上，打通"开始游戏"→"多设备共享对局"完整链路。所有客户端看到同一局面，轮到自己才能行动，任意座位行动后其他人实时同步。

## 核心设计决策

| 项 | 决策 | 理由 |
|---|---|---|
| 行动同步通道 | **REST 提交 + WS 广播** | 复用现有 `POST /actions` 规则引擎校验，后端执行后向房间广播新状态 |
| Bot/AI 座位驱动 | **后端开局自动驱动** | 轮到 Bot/AI 座位，后端自动调 `bot/act`/`ai/act` 并广播，不依赖客户端在线 |
| 对局中离开/断线 | **本地 Bot 接管该座位** | 对局不中断，该座位后续回合由后端自动驱动 |
| 开始门槛 | **仅房主可开始，≥2 座位** | 含 Bot/AI 即可开局，符合璀璨宝石 2-4 人规则 |
| 终局后房间状态 | **直接 finished** | 本期不做"再来一局"，终局后客户端返回首页 |

## 数据流

### 开始游戏流

```
房主点"开始游戏" → POST /api/online/rooms/:roomCode/start { clientId }
  ↓
后端校验：调用者是房主、房间 waiting、座位 ≥2
  ↓
座位按 seatIndex 升序映射成玩家：
  - human → { type: 'human' }
  - local_bot → { type: 'bot', botLevel: 'local' }
  - ai_player → { type: 'bot', botLevel: 'ai' }
  ↓
createSplendorSession({ playerCount, title, players })
  ↓
房间更新：status='playing', sessionId=新对局ID
  ↓
广播 WebSocket 事件：
  {
    type: 'game_started',
    room: { ...房间快照, status: 'playing', sessionId },
    sessionId: '...',
    state: { ...初始对局状态 }
  }
  ↓
若首位玩家是 Bot/AI → 后端自动驱动至真人回合
  - 每个 Bot 行动后广播 game_state_updated
  ↓
所有客户端收到 game_started → 跳转对局页(sessionId, clientId)
```

### 行动同步流

```
真人客户端提交 → POST /api/splendor/sessions/:id/actions
  {
    playerIndex: 0,
    action: { type: 'take_tokens', tokens: { white: 1, ... } }
  }
  ↓
后端规则引擎校验：
  - assertActiveTurn(state, playerIndex) // 含"not current player turn"检查
  - 行动合法性校验
  ↓
applySplendorAction(state, action) → 执行 → 写库
  ↓
notifyGameStateChanged(sessionId) // game-sync.ts 跨 feature 调用
  ↓
broadcastGameState(sessionId)
  - 读取最新 state
  - 广播 WebSocket 事件：
    {
      type: 'game_state_updated',
      room: { ...房间快照 },
      state: { ...最新对局状态 }
    }
  ↓
driveBotsUntilHumanTurn(sessionId)
  - 循环检查当前玩家 type
  - 若 Bot/AI → 调 actSplendorBot/actSplendorAiPlayer
  - 每次 Bot 行动后再次广播 game_state_updated
  - 直到轮到 human 或对局结束
  ↓
所有客户端收到 game_state_updated → 刷新 UI
```

### 断线接管流

```
WebSocket close → handleDisconnect(roomCode, clientId)
  ↓
查询房间 status
  ↓
若 status === 'waiting'：
  - 调用 leaveOnlineRoom({ roomCode, clientId })
  - 删除座位、广播 room_updated（现有逻辑）
  ↓
若 status === 'playing'：
  - 找到该 clientId 对应座位
  - 更新座位：controlType='local_bot', connected=false
  - 广播 room_updated（座位列表变化）
  - 若当前正是该座位回合 → 立即驱动一次 Bot 行动
  - 后续轮到该座位时后端会自动驱动（因为 controlType 已改）
```

### 终局流

```
某次行动后对局状态变为 finished
  ↓
broadcastGameState(sessionId) 检测到 state.status === 'finished'
  ↓
更新房间：status='finished'
  ↓
广播 WebSocket 事件：
  {
    type: 'game_finished',
    room: { ...房间快照, status: 'finished' },
    state: { ...终局状态, winner, scores }
  }
  ↓
客户端收到 game_finished → 展示结果面板 → 返回首页
```

## 后端实现

### 文件改动

| 文件 | 改动 |
|---|---|
| `features/online/types.ts` | +StartOnlineGameInput、+game_started/game_state_updated/game_finished 事件类型 |
| `features/online/service.ts` | +startOnlineGame、+broadcastGameState、+driveBotsUntilHumanTurn（导出） |
| `features/online/routes.ts` | +POST /start 接口、+handleDisconnect（区分 waiting/playing） |
| `features/online/game-sync.ts` | **新文件**，导出 notifyGameStateChanged 供 splendor 模块调用 |
| `features/splendor/routes.ts` | 行动提交后调用 notifyGameStateChanged + driveBotsUntilHumanTurn |

### 核心方法

#### startOnlineGame(input)

1. 校验：调用者是房主、房间 `waiting`、座位 ≥2
2. 座位映射：按 `seatIndex` 升序，`controlType` → `type`/`botLevel`
3. 创建对局：`createSplendorSession({ playerCount, title, players })`
4. 更新房间：`status='playing'`、`sessionId`
5. 广播：`game_started` 事件（带 `sessionId` 和初始 `state`）
6. 驱动 Bot：若首位是 Bot/AI，调 `driveBotsUntilHumanTurn`

#### broadcastGameState(sessionId)

1. 按 `sessionId` 查房间（`findFirst({ where: { sessionId } })`）
2. 读取最新对局状态：`getSplendorSession(sessionId)`
3. 若 `state.status === 'finished'` 且房间未 `finished`：
   - 更新房间 `status='finished'`
   - 广播 `game_finished`
4. 否则广播 `game_state_updated`

#### driveBotsUntilHumanTurn(sessionId)

1. 循环读取对局当前玩家
2. 若 `type === 'human'` 或对局 `finished` → 退出
3. 若 `botLevel === 'ai'` → 调 `actSplendorAiPlayer(sessionId)`
4. 否则 → 调 `actSplendorBot(sessionId)`
5. 每次 Bot 行动后调 `broadcastGameState(sessionId)`
6. 最多 50 轮防死循环

#### handleDisconnect(roomCode, clientId, app)

1. 查房间 status
2. 若 `waiting` → 调 `leaveOnlineRoom`（删座位）
3. 若 `playing`：
   - 找该 clientId 座位
   - 更新 `controlType='local_bot'`、`connected=false`
   - 广播 `room_updated`
   - 若当前正是该座位回合 → 立即驱动一次 Bot

### 跨 feature 调用

splendor 模块不直接依赖 online 模块，通过 `game-sync.ts` 中间层解耦：

```typescript
// features/online/game-sync.ts
export async function notifyGameStateChanged(sessionId: string): Promise<void> {
  await broadcastGameState(sessionId);
}
```

splendor routes.ts 在行动提交后：

```typescript
const result = await submitSplendorAction(sessionId, input);

// 广播给在线房间（若关联）
const { notifyGameStateChanged } = await import('../online/game-sync.js');
notifyGameStateChanged(sessionId).catch(...);

// 驱动 Bot 至真人回合
const { driveBotsUntilHumanTurn } = await import('../online/service.js');
driveBotsUntilHumanTurn(sessionId).catch(...);

return result;
```

## 前端实现（待补充）

本期后端已完成，前端待下次继续：

- `api/api_paths.dart`：+onlineRoomStart
- `api/online_api.dart`：+startGame 方法
- `models/online_room_models.dart`：+game_* 事件解析、+OnlineGameParams
- `pages/online_room/`：+开始游戏按钮（仅房主可见）、+监听 game_started 跳转
- `pages/splendor/table/`：+在线模式识别、+WS 事件订阅、+非己回合禁用

## 验证清单

### 后端验证（已完成）

- ✅ `npm run build` 无错误
- ✅ `npm test` 13 个测试全过

### 端到端验证（待前端完成后）

1. **开局流**：A 创建房间、B 加入 → A 点"开始游戏" → A/B 都跳进对局页，看到相同初始局面
2. **行动同步**：A 提交拿宝石 → B 端实时看到 A 拿了宝石且轮到 B
3. **Bot 自动驱动**：创建房间时加一个 Bot 座位 → 开局后 Bot 回合自动推进
4. **断线接管**：对局中某真人关页面 → 该座位后续回合由 Bot 接管，对局继续
5. **终局**：对局打到终局 → 双方收到 `game_finished`，房间 status=finished

## 暂不包含（明确延后）

- 断线后玩家重连恢复人控（要额外状态标记 + 权限转换）
- 终局后"再来一局"（要清理状态 + 重映射座位）
- 对局单开 WS 通道（复用房间通道即可）
- 观战者加入（座位已满的人进房间只能旁观）
- 多桌游支持（当前只有璀璨宝石）

## 技术债务与优化方向

1. **Bot 驱动时机**：当前在 splendor routes 里 fire-and-forget 调用，若驱动失败客户端无感知；可改为同步等待或返回错误。
2. **断线恢复**：当前 Bot 接管到终局，后续可加"重连恢复人控"（需座位 `takenOverAt` 字段和权限校验）。
3. **广播优化**：每次 Bot 行动都广播完整 state，可改为增量 diff 或批量合并（多个 Bot 连续行动只广播最后一次）。
4. **终局后流程**：当前房间直接 finished，可支持"再来一局"（清空 sessionId、重置座位状态、回到 waiting）。

## 相关文档

- [产品需求](product-requirements.md) — V4 联机对局需求
- [后端数据库设计](backend-database-design.md) — 在线房间表结构和接口
- [项目架构](project-architecture.md) — online 模块职责
- [前端架构](frontend-app-architecture.md) — 在线房间前端实现（待补充对局部分）
- 记忆：`memory/online-match-v4-decisions.md` — 核心业务决策
- 记忆：`memory/online-room-leave-behavior.md` — 房间离开行为
