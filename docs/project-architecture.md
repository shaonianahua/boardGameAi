# 项目架构设计

## 目标

本项目先实现本地可玩的 Flutter 桌游模拟器。当前只实现璀璨宝石，不接后端接口，不接 AI 模型。

整体架构需要保证：

- 游戏规则逻辑不写在 UI 组件里。
- 数据模型可以被页面、规则服务、后续 AI 模块复用。
- 可复用组件优先抽出来，避免相同功能写多份代码。
- 每个大目录和文件都要有清楚职责。

## 文档结构

```text
docs/
├── product-requirements.md
├── project-architecture.md
└── splendor/
    ├── README.md
    ├── design.md
    ├── card-data.md
    └── ai-primer.md
```

- `product-requirements.md`：项目整体需求方向。
- `project-architecture.md`：项目整体代码结构和分层说明。
- `splendor/`：璀璨宝石专属文档，包含规则、卡牌数据、AI 前置思路等。

## 代码结构

建议先采用以下结构：

```text
lib/
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
- 建立玩家操作记录。
- 建立拿宝石、预留、购买、贵族到访、终局判断。
- 建立最小页面展示。

暂不接入：

- 后端接口。
- AI 模型。
- 拍照识别。
- 联网对战。
