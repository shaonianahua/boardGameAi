# 后端数据库设计

版本：2026-06-17

## 设计目标

V1 的产品重点仍然是 Flutter App 内的本地同屏璀璨宝石对局，但项目需要保留完整的接口和数据库边界。后端在 V1 不承担复杂商业能力，而是承担三个作用：

- 为 Flutter 提供清晰、稳定的接口契约。
- 保存对局、玩家、回合动作和状态快照。
- 为后续 AI 玩家、AI 复盘和联机对战预留权威数据结构。

本阶段使用：

- Node.js
- Fastify
- Prisma
- SQLite

## 设计原则

- 前端是体验主角，后端是状态和接口边界。
- V1 先支持本地同屏对局，后续再扩展联机。
- 不把所有游戏细节过早拆成大量关系表。
- 固定卡牌和贵族数据作为 catalog 管理，不作为每局可变数据反复写库。
- 每局对局的权威状态使用 JSON 快照保存，方便快速恢复和调试。
- 每个玩家行动单独记录为 action log，方便回放、复盘、AI 分析和问题排查。
- 所有真人玩家和 AI 玩家都统一记录为 seat/player。
- 所有行动都使用统一 Action 协议，后续前端、后端、AI 共用。

## 为什么状态使用 JSON 快照

璀璨宝石的单局状态包含：

- 宝石池。
- 三级发展卡市场。
- 三个发展卡牌堆。
- 贵族区。
- 玩家宝石。
- 玩家已购买卡牌。
- 玩家预定卡牌。
- 当前玩家。
- 终局状态。

如果全部关系化，会在 V1 阶段制造大量表和联表查询，但实际收益有限。更适合的方式是：

- 用关系表保存对局、玩家、动作这些需要查询和索引的实体。
- 用 JSON 保存完整 `GameState` 快照。
- 固定卡牌 ID 和贵族 ID 在 JSON 中引用 catalog。

这样前端、后端、AI 都可以围绕同一个结构化 `GameState` 工作。

## 表设计

### `game_sessions`

保存一局游戏的基本信息和当前状态。

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 对局 ID |
| `gameType` | string | 游戏类型，V1 固定为 `splendor` |
| `title` | string? | 对局标题 |
| `status` | string | `active` / `finished` / `abandoned` |
| `playerCount` | int | 玩家人数，2-4 |
| `currentTurnIndex` | int | 当前回合序号，从 0 开始 |
| `currentPlayerIndex` | int | 当前玩家座位序号 |
| `winnerPlayerIndex` | int? | 胜者座位序号，未结束为空 |
| `stateJson` | string | 当前完整 GameState JSON |
| `createdAt` | datetime | 创建时间 |
| `updatedAt` | datetime | 更新时间 |
| `finishedAt` | datetime? | 结束时间 |

索引：

- `gameType`
- `status`
- `updatedAt`

### `game_players`

保存某局中的玩家座位。

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 玩家记录 ID |
| `sessionId` | string | 所属对局 ID |
| `seatIndex` | int | 座位序号，从 0 开始 |
| `name` | string | 玩家名称 |
| `playerType` | string | `human` / `bot` |
| `botLevel` | string? | Bot 难度或策略风格，真人为空 |
| `createdAt` | datetime | 创建时间 |

约束：

- 同一局内 `seatIndex` 唯一。

### `game_actions`

保存每一步行动日志。

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 行动记录 ID |
| `sessionId` | string | 所属对局 ID |
| `turnIndex` | int | 回合序号 |
| `playerIndex` | int | 行动玩家座位序号 |
| `actorType` | string | `human` / `bot` / `llm` / `system` |
| `actionType` | string | `take_tokens` / `reserve_card` / `buy_card` / `discard_tokens` / `choose_noble` / `noble_visit` |
| `actionJson` | string | 行动参数 JSON |
| `stateBeforeJson` | string | 行动前状态快照 |
| `stateAfterJson` | string | 行动后状态快照 |
| `createdAt` | datetime | 创建时间 |

索引：

- `sessionId, turnIndex`
- `sessionId, playerIndex`
- `actionType`

说明：

- V1 中一个玩家回合一般对应一个主行动。
- 如果行动后需要弃宝石，可以作为同一回合内的后续 action 记录。
- 贵族获得由规则服务自动写入状态，并追加一条 `actorType: system`、`actionType: noble_visit` 的行动记录，不要求玩家提交选择贵族 action。
- 后续做回放时，优先读取 `game_actions`。

### `ai_decisions`

保存 AI 思考记录。V1 可暂时不使用，V2/V3 开始使用。

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | AI 记录 ID |
| `sessionId` | string | 所属对局 ID |
| `actionId` | string? | 对应行动 ID |
| `playerIndex` | int | AI 所在座位 |
| `provider` | string | `heuristic` / `gemini` / `qwen` / `local_model` |
| `model` | string? | 具体模型名 |
| `inputJson` | string | 输入给 AI 的结构化数据 |
| `outputJson` | string | AI 输出 |
| `selectedActionJson` | string | 最终选择的行动 |
| `tokenUsageJson` | string? | 云模型 token 使用量 |
| `createdAt` | datetime | 创建时间 |

说明：

- 本地启发式 AI 不消耗 token，`tokenUsageJson` 为空。
- 云端 LLM 需要记录 token 使用，方便分析成本。
- 如果 LLM 输出非法行动，仍记录原始输出，并在业务层回退到启发式 AI。

### `online_rooms`

保存联机对战的房间大厅信息。V4 第一阶段只负责创建房间、加入房间和订阅房间状态，不在这里直接处理游戏行动。

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 房间 ID |
| `roomCode` | string | 6 位加入码，给其他设备输入加入房间 |
| `gameType` | string | 游戏类型，当前默认 `splendor` |
| `status` | string | `waiting` / `playing` / `finished` / `closed` |
| `hostSeatIndex` | int? | 房主座位，创建房间时默认为 0 |
| `sessionId` | string? | 房间开始游戏后关联的 `game_sessions.id`，等待大厅阶段为空 |
| `createdAt` | datetime | 创建时间 |
| `updatedAt` | datetime | 更新时间 |

索引：

- `roomCode` 唯一。
- `gameType`
- `status`
- `updatedAt`

### `online_room_seats`

保存联机房间里的座位信息。这里的座位是大厅座位，开始游戏后再映射为 `game_players`。

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | 座位记录 ID |
| `roomId` | string | 所属房间 ID |
| `seatIndex` | int | 座位序号，当前 MVP 为 0-3 |
| `playerName` | string | 玩家展示名称 |
| `clientId` | string | 客户端临时标识，用于重复进入时找回原座位 |
| `controlType` | string | `human` / `local_bot` / `ai_player` |
| `ready` | boolean | 是否准备，第一阶段先保留字段但不做准备逻辑 |
| `connected` | boolean | 是否在线，第一阶段进入房间时置为 true |
| `createdAt` | datetime | 创建时间 |
| `updatedAt` | datetime | 更新时间 |

约束：

- 同一房间内 `seatIndex` 唯一。
- 同一房间内 `clientId` 唯一，方便断线重进或重复加入时更新原座位。

## 固定 Catalog 数据

V1 不建议把 90 张发展卡和 10 个贵族作为关系表管理，优先放在代码或 seed JSON 中：

```text
data/seeds/splendor_cards.json
data/seeds/splendor_nobles.json
```

每张发展卡建议字段：

```json
{
  "id": "dev-1-001",
  "level": 1,
  "bonusColor": "white",
  "prestige": 0,
  "cost": {
    "white": 0,
    "blue": 3,
    "green": 0,
    "red": 0,
    "black": 0
  }
}
```

每个贵族建议字段：

```json
{
  "id": "noble-001",
  "prestige": 3,
  "requirement": {
    "white": 3,
    "blue": 3,
    "green": 0,
    "red": 0,
    "black": 3
  }
}
```

后续如果需要后台管理卡牌数据，再迁移成关系表。

## GameState JSON 结构

`game_sessions.stateJson` 建议保存如下结构：

```json
{
  "gameType": "splendor",
  "status": "active",
  "playerCount": 4,
  "currentTurnIndex": 0,
  "currentPlayerIndex": 0,
  "tokenPool": {
    "white": 7,
    "blue": 7,
    "green": 7,
    "red": 7,
    "black": 7,
    "gold": 5
  },
  "markets": {
    "level1": ["dev-1-001", "dev-1-002", "dev-1-003", "dev-1-004"],
    "level2": ["dev-2-001", "dev-2-002", "dev-2-003", "dev-2-004"],
    "level3": ["dev-3-001", "dev-3-002", "dev-3-003", "dev-3-004"]
  },
  "decks": {
    "level1": ["dev-1-005"],
    "level2": ["dev-2-005"],
    "level3": ["dev-3-005"]
  },
  "nobles": ["noble-001", "noble-002", "noble-003", "noble-004", "noble-005"],
  "players": [
    {
      "seatIndex": 0,
      "name": "玩家1",
      "type": "human",
      "score": 0,
      "tokens": {
        "white": 0,
        "blue": 0,
        "green": 0,
        "red": 0,
        "black": 0,
        "gold": 0
      },
      "bonuses": {
        "white": 0,
        "blue": 0,
        "green": 0,
        "red": 0,
        "black": 0
      },
      "purchasedCards": [],
      "reservedCards": [],
      "nobles": []
    }
  ],
  "finalRound": {
    "triggered": false,
    "triggeredByPlayerIndex": null,
    "roundEndPlayerIndex": null
  },
  "pendingAction": null,
  "winnerPlayerIndex": null
}
```

`pendingAction` 用于表达主行动后还必须由当前玩家继续处理的步骤。V1 当前实际使用弃宝石 pending：

```json
{
  "type": "discard_tokens",
  "playerIndex": 0,
  "tokenCount": 12,
  "maxTokenCount": 10
}
```

说明：

- `pendingAction` 不为空时，不推进到下一位玩家。
- 前端必须先提交对应的 `discard_tokens` action。
- 后端处理完 pending action 后，才会推进回合或结算终局。
- 贵族卡不再进入 pending；玩家可选操作和必要弃宝石完成后，由后端自动判断是否获得场上贵族，一个回合最多获得 1 张。

## Action JSON 结构

所有玩家行动统一通过 `actionJson` 表达。

### 拿宝石

```json
{
  "type": "take_tokens",
  "tokens": {
    "white": 1,
    "blue": 1,
    "green": 1
  }
}
```

### 预定卡

```json
{
  "type": "reserve_card",
  "source": "market",
  "cardId": "dev-2-001",
  "level": 2
}
```

盲抽预定：

```json
{
  "type": "reserve_card",
  "source": "deck",
  "level": 2
}
```

### 购买卡

```json
{
  "type": "buy_card",
  "source": "market",
  "cardId": "dev-2-001",
  "payment": {
    "white": 0,
    "blue": 2,
    "green": 1,
    "red": 0,
    "black": 0,
    "gold": 1
  }
}
```

### 弃宝石

```json
{
  "type": "discard_tokens",
  "tokens": {
    "white": 1
  }
}
```

## V1 推荐接口边界

### 创建对局

```text
POST /api/splendor/sessions
```

请求：

```json
{
  "playerCount": 4,
  "players": [
    { "name": "玩家1", "type": "human" },
    { "name": "玩家2", "type": "human" },
    { "name": "玩家3", "type": "human" },
    { "name": "玩家4", "type": "human" }
  ]
}
```

返回：

```json
{
  "sessionId": "xxx",
  "state": {}
}
```

### 获取对局

```text
GET /api/splendor/sessions/:sessionId
```

返回当前 `GameState` 和玩家信息。

### 提交行动

```text
POST /api/splendor/sessions/:sessionId/actions
```

请求：

```json
{
  "playerIndex": 0,
  "action": {
    "type": "take_tokens",
    "tokens": {
      "white": 1,
      "blue": 1,
      "green": 1
    }
  }
}
```

返回：

```json
{
  "state": {},
  "actionRecord": {}
}
```

### 获取合法行动

```text
GET /api/splendor/sessions/:sessionId/legal-actions
```

返回当前玩家可执行行动。如果 `state.pendingAction` 不为空，只返回 pending action 对应的合法行动。

返回：

```json
{
  "playerIndex": 0,
  "pendingAction": null,
  "actions": [
    {
      "action": {
        "type": "take_tokens",
        "tokens": {
          "white": 1,
          "blue": 1,
          "green": 1
        }
      },
      "label": "Take white, blue, green"
    }
  ],
  "disabledReasons": []
}
```

### 获取行动历史

```text
GET /api/splendor/sessions/:sessionId/actions
```

返回按 `turnIndex` 和创建时间排序的行动记录，包含玩家提交行动和系统自动事件，例如 `noble_visit`。

### AI 建议或 AI 行动

V1 可以暂不实现，V2 开始使用。V2 先支持真人玩家请求 AI 建议，V3 再扩展为大模型接管 Bot 或复盘分析：

```text
POST /api/splendor/sessions/:sessionId/ai/decide
```

请求中的 `mode` 用于区分使用方式：

- `suggest`：只返回推荐行动、解释、备选方案、对手威胁和风险提示，不执行行动。
- `execute`：AI 选择行动后由后端再次校验并执行，写入行动历史；V2 可先不开放给真人建议。

返回 AI 选中的合法行动和解释。若模型返回的 `actionId` 无法匹配合法行动，后端或前端不能执行该行动，只能展示解释或回退到本地启发式 Bot。

后续如需要更出彩的展示效果，可增加流式建议接口：

```text
POST /api/splendor/sessions/:sessionId/ai/stream
```

流式接口用于前端策略面板逐段展示结论、理由、对手威胁和风险；最终仍要返回可校验的结构化 `decision`。

## V4 在线房间第一阶段接口

第一阶段只做等待大厅，不创建真实对局，也不提交在线行动。

### 创建房间

```text
POST /api/online/rooms
```

请求：

```json
{
  "gameType": "splendor",
  "hostName": "玩家1",
  "clientId": "device-client-id"
}
```

返回：

```json
{
  "id": "room-id",
  "roomCode": "A2B3C4",
  "gameType": "splendor",
  "status": "waiting",
  "hostSeatIndex": 0,
  "sessionId": null,
  "seats": []
}
```

说明：

- 创建者自动占用 0 号座位。
- `clientId` 不传时后端会生成一个临时值并返回在座位信息里，前端后续应本地保存并复用。

### 加入房间

```text
POST /api/online/rooms/join
```

请求：

```json
{
  "roomCode": "A2B3C4",
  "playerName": "玩家2",
  "clientId": "device-client-id",
  "controlType": "human"
}
```

说明：

- 房间必须处于 `waiting`。
- 重复 `clientId` 加入同一个房间时，不新增座位，只更新原座位名称、控制类型和在线状态。
- 当前最多 4 个座位，分配最小可用座位号。

### 查询房间

```text
GET /api/online/rooms/:roomCode
```

返回当前房间快照，供进入房间页或刷新时使用。

### 离开房间

```text
POST /api/online/rooms/leave
```

请求：

```json
{
  "roomCode": "A2B3C4",
  "clientId": "device-client-id"
}
```

说明：

- 按 `clientId` 删除当前设备座位，并向房间内其他在线订阅者广播 `room_updated`。
- 离开者是房主时，把房主转移给剩余最小座位号的玩家，房间继续等待。
- 房间所有座位删空时，房间 `status` 置为 `closed`，已 closed 的房间无法再加入。
- 座位已不存在时幂等返回当前快照，不重复广播。

### 订阅房间事件

```text
WebSocket /api/online/rooms/:roomCode/events
```

连接可带 `?clientId=...` 查询参数。连接后服务端会先发送：

```json
{
  "type": "room_snapshot",
  "room": {}
}
```

当有人加入、离开或重复进入导致座位变化时，服务端广播：

```json
{
  "type": "room_updated",
  "room": {}
}
```

说明：

- 当前事件只同步房间大厅状态。
- socket 断开（关 App、断网、切走页面）时，若连接带了 `clientId`，后端会先取消订阅，再用该 `clientId` 删除座位并广播，作为离开兜底。
- 开始游戏、行动提交和 GameState 广播放到下一阶段设计。

## Prisma 初步模型

后续实现后端时，建议将当前简单的 `GameSession` / `GameTurn` 替换为：

```text
GameSession
GamePlayer
GameAction
AiDecision
```

其中：

- `GameSession.stateJson` 保存当前状态。
- `GameAction.stateBeforeJson` 和 `GameAction.stateAfterJson` 保存动作前后状态。
- `AiDecision` 从 V2 开始使用。

## 暂不设计的内容

- 用户账号。
- 远程房间匹配。
- 好友系统。
- 线上支付。
- 云端同步。
- 多桌游通用平台抽象。

这些能力会显著增加复杂度，不符合当前作品项目的重点。
