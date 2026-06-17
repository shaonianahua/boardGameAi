# V1 后端实现说明

版本：2026-06-17

## 实现范围

本阶段完成了 V1 后端的基础闭环：

- Node.js + Fastify 服务。
- Prisma + SQLite 数据库。
- 璀璨宝石固定 catalog：90 张发展卡、10 个贵族。
- 创建本地对局。
- 查询对局。
- 提交玩家行动。
- 查询当前合法行动。
- 查询行动历史。
- 保存当前 `GameState` 快照。
- 保存每一步行动的前后状态快照。

当前后端用于建立前后端接口契约和存档能力，不承担线上联机能力。

## 代码结构

```text
backend/
├── package.json
├── prisma/
│   ├── schema.prisma
│   └── migrations/
└── src/
    ├── server.ts
    ├── db/
    │   └── prisma.ts
    └── features/
        └── splendor/
            ├── catalog.ts
            ├── routes.ts
            ├── rules.ts
            ├── service.ts
            ├── state.ts
            └── types.ts
```

文件职责：

- `server.ts`：Fastify 服务入口，注册健康检查和璀璨宝石接口。
- `db/prisma.ts`：PrismaClient 单例。
- `features/splendor/catalog.ts`：璀璨宝石固定卡牌和贵族数据。
- `features/splendor/types.ts`：GameState、Action、玩家、卡牌等 TypeScript 类型。
- `features/splendor/state.ts`：创建初始对局状态、状态序列化和反序列化。
- `features/splendor/rules.ts`：行动合法性校验和状态推进。
- `features/splendor/service.ts`：数据库读写和业务编排。
- `features/splendor/routes.ts`：HTTP 路由。

## 数据库模型

当前 Prisma 模型：

- `GameSession`：一局游戏，保存当前状态快照。
- `GamePlayer`：一局游戏内的玩家座位。
- `GameAction`：每一步行动日志，保存行动前后状态。
- `AiDecision`：为 V2/V3 AI 玩家和 LLM 思考记录预留。

SQLite 数据库路径：

```text
data/sqlite/boardgameai.db
```

真实数据库文件被 `.gitignore` 忽略，不提交。

## 已实现接口

### 健康检查

```text
GET /health
```

### 获取固定数据

```text
GET /api/splendor/catalog
```

返回：

- `cards`：90 张发展卡。
- `nobles`：10 个贵族。

### 创建对局

```text
POST /api/splendor/sessions
```

请求：

```json
{
  "playerCount": 2,
  "players": [
    { "name": "A", "type": "human" },
    { "name": "B", "type": "human" }
  ]
}
```

返回：

- `session`：对局摘要。
- `players`：玩家座位记录。
- `state`：完整 `GameState`。

### 获取对局

```text
GET /api/splendor/sessions/:sessionId
```

返回当前对局状态。

### 提交行动

```text
POST /api/splendor/sessions/:sessionId/actions
```

请求示例：

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

- `session`：更新后的对局摘要。
- `actionRecord`：结构化行动记录。
- `state`：更新后的完整 `GameState`。

### 查询合法行动

```text
GET /api/splendor/sessions/:sessionId/legal-actions
```

返回：

- `playerIndex`：当前行动玩家座位。
- `pendingAction`：当前待处理动作，为空表示可执行主行动。
- `actions`：当前可提交的合法 Action 列表。
- `disabledReasons`：无可行动作或状态不可行动时的原因。

### 查询行动历史

```text
GET /api/splendor/sessions/:sessionId/actions
```

返回结构化行动历史，每条记录包含：

- `action`
- `stateBefore`
- `stateAfter`

说明：

- 玩家提交行动会记录为 `human` / `bot` / `llm` 等 actorType。
- 自动获得贵族会追加 `actorType: system`、`action.type: noble_visit` 的系统行动记录，方便前端和后续 AI 回看完整过程。

## 当前规则能力

已实现：

- 初始化不同人数的宝石数量。
- 洗牌和市场发牌。
- 按人数翻出贵族。
- 拿最多 3 个不同色宝石；如果公共池非黄金宝石只剩 1-2 种颜色，则可拿对应数量的不同色宝石。
- 拿 2 个同色宝石，要求公共池该色至少 4 个。
- 预定市场卡或盲抽牌堆卡。
- 预定时拿黄金，黄金为空则只预定。
- 购买公开卡或预定卡。
- 自动使用支付信息或默认支付。
- 折扣、扣宝石、回宝石池。
- 购买后获得 bonus 和分数。
- 购买市场卡后补牌。
- 玩家可选行动执行完毕，且必要弃宝石处理完毕后，自动判断是否满足场上贵族；一个回合最多获得 1 张贵族。
- 同时满足多个贵族时，按当前场上贵族顺序自动获得第 1 张，获得后从场上移除；不满足条件则跳过且不产生提示。
- 自动获得贵族会写入行动历史，action type 为 `noble_visit`。
- 行动后超过 10 个 token 时进入 `pendingAction: discard_tokens`，等待玩家弃宝石；玩家回合开始时即使已有 10 个 token，也可以先拿宝石再弃到 10。
- 15 分终局触发和胜负结算基础逻辑。
- 行动后推进当前玩家。
- 查询当前合法行动。

当前测试：

- `src/features/splendor/__tests__/rules.test.ts` 覆盖初始合法行动、公共池只剩两色时拿两个不同色、10 个 token 开始拿宝石后弃牌、弃宝石 pending、多贵族自动获得和自动贵族历史事件识别。

当前限制：

- 没有实现 Bot 或 AI 决策接口。

这些限制不影响 V1 后端接口骨架，但前端开发前需要逐项补齐或明确交互方式。

## 验证结果

已验证：

```text
npm run build
npm test
```

通过。

已验证接口：

- `GET /api/splendor/catalog` 返回 `90 10`。
- 创建 4 人对局后，牌堆数量为：
  - level1：市场 4，牌堆 36
  - level2：市场 4，牌堆 26
  - level3：市场 4，牌堆 16
  - 贵族 5
- 提交 `take_tokens` 后：
  - 当前玩家从 0 推进到 1
  - 公共白宝石从 4 变 3
  - 玩家 0 白宝石从 0 变 1
  - 行动历史记录成功写入

## 本地运行

```bash
cd backend
npm install
npm run prisma:migrate
npm run build
npm start
```

开发模式：

```bash
npm run dev
```

## 下一步建议

前端开发前，建议后端继续补：

- 弃宝石流程。
- 多贵族选择流程。
- 合法行动枚举接口。
- 基础规则单元测试。
- 更明确的错误码。

之后再进入 Flutter 前端开发：

- 先接 `catalog`。
- 再接创建对局。
- 再做对局页状态展示。
- 最后接提交行动。
