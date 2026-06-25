# 项目架构设计

## 目标

本项目先实现本地可玩的 Flutter 桌游模拟器。当前只实现璀璨宝石，后端和数据库作为后续联机、存档和 AI 代理的支撑能力存在；前端仍是第一阶段重点。

整体架构需要保证：

- 游戏规则逻辑不写在 UI 组件里。
- 数据模型可以被页面、规则服务、后续 AI 模块复用。
- 可复用组件优先抽出来，避免相同功能写多份代码。
- 每个大目录和文件都要有清楚职责。
- 所有真人和 AI 行动都通过统一 Action 协议执行。
- AI 只能在规则引擎生成的合法行动中选择，不直接修改 GameState。

## 文档结构

```text
docs/
├── product-requirements.md
├── project-architecture.md
├── backend-database-design.md
├── backend-implementation-v1.md
├── ai-integration-plan.md
└── splendor/
    ├── README.md
    ├── design.md
    ├── card-data.md
    └── ai-primer.md
```

- `product-requirements.md`：项目整体需求方向。
- `project-architecture.md`：项目整体代码结构和分层说明。
- `backend-database-design.md`：V1 后端数据库、GameState、Action 和接口边界设计。
- `backend-implementation-v1.md`：V1 后端代码实现、接口、验证结果和当前限制。
- `ai-integration-plan.md`：DeepSeek 等模型接入计划、prompt 位置、AI 边界和后续模块设计。
- `splendor/`：璀璨宝石专属文档，包含规则、卡牌数据、AI 前置思路等。

## 代码结构

当前仓库采用单仓库结构：

```text
boardGameAi/
├── frontend/
├── backend/
├── data/
└── docs/
```

目录职责：

- `frontend/`：Flutter App，是当前阶段的核心。
- `backend/`：本地后端，后续用于存档、AI 代理、联机权威状态。
- `data/`：SQLite 数据库、种子数据、对局快照。
- `docs/`：需求、架构、规则、AI 策略文档。

Flutter 端建议先采用以下结构：

```text
frontend/lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── routes.dart
│   └── theme.dart
├── models/
│   └── splendor/
├── pages/
│   └── splendor/
├── services/
│   └── splendor/
└── shared/
    ├── widgets/
    └── utils/
```

## 目录职责

### `lib/app/`

App 级入口配置。

- `app.dart`：创建 Flutter App 外壳，后续承载 `GetMaterialApp`、全局路由、主题等。
- `routes.dart`：统一维护页面路由名称和路由表。
- `theme.dart`：统一维护颜色、字体、组件主题等全局视觉配置。

### `lib/models/`

项目数据模型目录。

不同桌游按子目录区分。例如：

```text
models/
└── splendor/
```

`models/splendor/` 放璀璨宝石的纯数据结构，例如宝石、卡牌、贵族、玩家、对局状态、玩家动作、操作记录。

模型层不依赖 Flutter 页面，也不写规则判断。

### `lib/pages/`

页面目录。

不同桌游按子目录区分。例如：

```text
pages/
└── splendor/
```

`pages/splendor/` 放璀璨宝石相关页面、Controller 和页面内组件。

页面层负责展示和交互，不直接承载复杂规则。用户点击后，页面或 Controller 调用 `services/splendor/` 完成规则判断和状态变更。

### `lib/services/`

业务服务目录。

不同桌游按子目录区分。例如：

```text
services/
└── splendor/
```

`services/splendor/` 放璀璨宝石的固定数据、规则判断、对局推进逻辑。

第一阶段不拆太碎，建议先保留少量文件：

- `splendor_catalog.dart`：固定卡牌和贵族数据。
- `splendor_rule_service.dart`：动作是否合法、支付是否足够、贵族是否满足、终局是否触发等规则判断。
- `splendor_game_service.dart`：创建新对局、执行动作、推进回合、写入操作记录。
- `splendor_action_generator.dart`：根据当前状态枚举合法行动。
- `splendor_ai_service.dart`：本地启发式 AI，基于合法行动评分，不调用大模型。

当前后端 V2 已新增：

- `backend/src/features/splendor/bot-advisor.ts`：本地 Bot 启发式策略，从后端合法行动列表中选择行动，不直接修改 `GameState`。
- `POST /api/splendor/sessions/:sessionId/bot/act`：当前玩家是 Bot 时自动选择并执行一个合法行动；行动仍通过规则引擎校验和记录。

### `backend/src/features/online/`

联机对战房间模块。V4 第一阶段只负责等待大厅能力：创建房间、加入房间、查询房间和订阅房间事件。

文件职责：

- `types.ts`：在线房间的请求体、公开返回结构和 WebSocket 事件类型。接口字段必须和数据库字段、前端模型保持一致，不随意扩展。
- `service.ts`：在线房间业务逻辑。负责生成房间码、创建房间、加入房间、重复 clientId 找回座位、离开房间删座位与房主转移、转换公开房间快照。
- `room-events.ts`：房间 WebSocket 订阅管理。当前使用内存 `Map<roomId, Set<WebSocket>>` 保存订阅者，并负责广播房间更新事件。
- `routes.ts`：在线房间接口入口。注册 REST 接口和 WebSocket 订阅入口，把异常转换为统一错误返回。

核心方法：

- `createOnlineRoom(input)`：创建等待中的联机房间，并把创建者放到 0 号座位。
- `joinOnlineRoom(input)`：加入等待中的房间；如果同一 `clientId` 已在房间中，则更新原座位而不是新增座位。
- `leaveOnlineRoom(input)`：按 `clientId` 删除座位并广播 `room_updated`；离开者是房主时把房主转移给剩余最小座位号，房间清空时置为 `closed`；座位已不存在时幂等返回不广播，兼容主动离开后 WebSocket 断线再触发一次。
- `getOnlineRoomByCode(roomCode)`：按房间码读取公开房间快照。
- `subscribeOnlineRoom(roomId, socket)`：把 WebSocket 连接加入指定房间订阅集合。
- `unsubscribeOnlineRoom(roomId, socket)`：连接关闭时移除订阅关系。
- `broadcastOnlineRoomEvent(roomId, event)`：向房间内所有在线订阅者发送房间事件。

当前接口：

- `POST /api/online/rooms`：创建房间。
- `POST /api/online/rooms/join`：加入房间。
- `POST /api/online/rooms/leave`：离开房间，删除当前设备座位并广播给其他玩家。
- `GET /api/online/rooms/:roomCode`：查询房间。
- `WebSocket /api/online/rooms/:roomCode/events`：订阅房间快照和更新事件；连接可带 `clientId` 查询参数，socket 断开时后端据此删除对应座位作为离开兜底。

暂不包含：

- 在线开始游戏。
- 在线提交行动。
- GameState 实时广播。
- 账号、好友、匹配、聊天。

### `lib/shared/`

真正跨页面、跨游戏复用的内容。

- `widgets/`：通用 UI 组件。
- `utils/`：通用工具函数。

不确定能否复用的代码先放在具体模块内，等第二处真实复用出现后再抽到 `shared/`。

## 璀璨宝石第一阶段重点

第一阶段先做纯本地游戏本体：

- 建立模型。
- 建立固定卡牌和贵族数据。
- 建立对局初始化逻辑。
- 建立统一 Action 协议和玩家操作记录。
- 建立拿宝石、预留、购买、贵族到访、终局判断。
- 建立最小页面展示。
- 建立可测试的合法行动枚举。

暂不接入：

- AI 模型。
- 拍照识别。
- 联网对战。

## Bot 与 AI 建议架构

AI 玩家不应直接操作页面，也不应直接修改 `GameState`。AI 玩家和真人玩家一样，只能提交 `Action`。

推荐流程：

```text
GameState
  -> SplendorActionGenerator 生成合法行动
  -> Human UI 或 AI Player 选择一个 Action
  -> SplendorRuleService 校验 Action
  -> SplendorGameService 执行 Action
  -> 生成新的 GameState
```

### V2：本地 Bot

本地 AI 只依赖规则引擎和评分函数：

```text
legalActions = generateLegalActions(gameState)
scoredActions = legalActions.map(scoreAction)
selectedAction = pickBest(scoredActions)
```

评分维度可以包括：

- 当前行动能否直接得分。
- 是否缩短购买高分卡的回合数。
- 是否推进贵族需求。
- 是否减少 token 浪费。
- 是否阻断对手关键卡。
- 是否接近或触发终局。

本地启发式 AI 不消耗 token，适合做默认 Bot。

本地 Bot 的定位是“自动玩家”和“模型失败兜底”。它可以有简单策略评分，但不要直接写入 UI，也不要绕过合法行动校验。

### V2：AI 策略建议

AI 策略建议面向真人玩家，点击后读取当前结构化对局，返回推荐行动和解释。V2 中它先不默认代替玩家执行操作。

```text
GameState + catalog + legalActions + actionHistory
  -> backend advisor-service
  -> cloud LLM
  -> structured advice
  -> Flutter AI advice panel streaming display
```

建议输出需要包含：

- `actionId`：推荐的合法行动 ID；如果没有足够信心可以为空。
- `summary`：一句话推荐。
- `reasoning`：为什么这么做，包括得分、折扣、贵族路线或节奏收益。
- `alternatives`：备选行动。
- `threats`：其他玩家可能想买的卡或即将达成的贵族。
- `risks`：推荐行动的风险。
- `highlightTargets`：后续可选，用于让前端高亮相关卡牌或宝石；是否加字段必须结合接口实现再确认。

约束：

- 大模型只能推荐后端提供的合法行动，不能自己编造行动。
- 后端必须校验模型返回的 `actionId` 是否在合法行动列表中。
- 如果模型返回非法行动，前端只能展示文字，不提供“采纳执行”。
- V2 第一版可以先非流式返回完整建议；之后升级为流式输出。

### V3：LLM 增强 AI

大模型只负责增强选择和解释：

```text
GameState + TopN合法候选行动 + 简短策略上下文
  -> LLM
  -> 推荐行动 + 原因 + 备选 + 风险
```

模型输出必须经过结构化解析和合法性校验：

- 输出行动必须存在于合法行动列表。
- 输出字段必须符合约定 schema。
- 如果模型返回非法行动，回退到本地启发式 AI。

V3 与 V2 AI 建议的区别：

- V2：真人点击“AI 建议”，模型只建议，用户自己决定是否执行。
- V3：模型可以接管 Bot 座位，后端校验后自动执行，并记录 AI 决策过程。

### 后端定位

当前阶段后端不是作品重点。它负责为后续能力预留：

- 本地 SQLite 存档。
- AI API 代理，避免 API Key 放在前端。
- 后续联机时保存权威 GameState。

联机阶段，前端仍可做即时合法性提示，但后端必须作为最终裁判重新校验 Action。
