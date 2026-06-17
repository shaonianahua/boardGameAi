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

## AI 玩家架构

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

### V2：本地启发式 AI

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

### 后端定位

当前阶段后端不是作品重点。它负责为后续能力预留：

- 本地 SQLite 存档。
- AI API 代理，避免 API Key 放在前端。
- 后续联机时保存权威 GameState。

联机阶段，前端仍可做即时合法性提示，但后端必须作为最终裁判重新校验 Action。
