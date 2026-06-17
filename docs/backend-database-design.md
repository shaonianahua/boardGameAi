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
| `actorType` | string | `human` / `bot` / `llm` |
| `actionType` | string | `take_tokens` / `reserve_card` / `buy_card` / `discard_tokens` / `choose_noble` |
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
- 如果行动后需要弃宝石或选择贵族，可以作为同一回合内的后续 action 记录。
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
  "winnerPlayerIndex": null
}
```

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

### 选择贵族

```json
{
  "type": "choose_noble",
  "nobleId": "noble-001"
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

### 获取行动历史

```text
GET /api/splendor/sessions/:sessionId/actions
```

返回按 `turnIndex` 排序的行动记录。

### AI 建议或 AI 行动

V1 可以暂不实现，V2/V3 使用：

```text
POST /api/splendor/sessions/:sessionId/ai/decide
```

返回 AI 选中的合法行动和解释。

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

