# Flutter App 架构索引

版本：2026-06-18

## 使用要求

每次处理 Flutter App 相关任务前，必须先阅读本文件和仓库根目录的 `AGENTS.md`。

本文件用于记录 `frontend/lib/` 下的 App 架构、文件职责、核心类、核心方法、可复用 widget 和使用方式。后续新增或修改页面、路由、主题、模型、服务、公共组件时，都要同步更新本文件。

后续新增或修改 API、model、组件、widget、公共功能方法、核心业务方法时，代码里必须保留最基本的备注信息，说明用途、输入输出、对应接口或使用场景，保证后续阅读和复用时不费劲。

## 当前目标

当前 App 已进入璀璨宝石 V2 规划阶段。V1 已完成本地同屏对局主流程，V2 前端重点是：

- 页面展示和交互。
- 创建对局时支持真人 / Bot 座位。
- Bot 回合自动推进，并展示“Bot 思考中”和行动结果。
- 真人回合支持“AI 建议”入口。
- AI 建议面板展示推荐行动、理由、备选行动、对手威胁和风险。
- 后续流式输出和桌面元素高亮可以复用同一套建议模型。

暂不在首页或 UI 组件里写复杂规则逻辑。页面负责展示和收集用户操作，规则判断和状态变更放到 `services/`。

## 目录总览

```text
frontend/lib/
├── main.dart
├── api/
│   ├── api_config.dart
│   ├── api_paths.dart
│   └── splendor_api.dart
├── app/
│   ├── app_colors.dart
│   ├── app.dart
│   ├── routes.dart
│   └── theme.dart
├── models/
│   ├── api_models.dart
│   ├── splendor_action_models.dart
│   ├── splendor_base_models.dart
│   ├── splendor_catalog_models.dart
│   ├── splendor_models.dart
│   ├── splendor_session_models.dart
│   └── splendor_state_models.dart
├── pages/
│   ├── index/
│   │   └── index_page.dart
│   └── splendor/
│       ├── splendor_table_page.dart
│       ├── create_session/
│       │   ├── controller/
│       │   │   └── splendor_create_session_controller.dart
│       │   ├── player_count_selector.dart
│       │   └── splendor_create_session_page.dart
│       └── table/
│           ├── actions/
│           │   ├── card_actions_sheet.dart
│           │   ├── discard_tokens_panel.dart
│           │   ├── legal_actions_panel.dart
│           │   └── take_tokens_panel.dart
│           ├── controller/
│           │   └── splendor_table_controller.dart
│           ├── splendor_card_style_helpers.dart
│           ├── splendor_catalog_lookup.dart
│           └── widgets/
│               ├── splendor_action_history_panel.dart
│               ├── splendor_ai_advice_panel.dart
│               ├── splendor_cost_chip.dart
│               ├── splendor_cost_wrap.dart
│               ├── splendor_development_card_tile.dart
│               ├── splendor_game_result_panel.dart
│               ├── splendor_gem_chip.dart
│               ├── splendor_info_card.dart
│               ├── splendor_market_card.dart
│               ├── splendor_market_section.dart
│               ├── splendor_noble_card.dart
│               ├── splendor_noble_tile.dart
│               ├── splendor_player_assets_panel.dart
│               ├── splendor_player_summary_card.dart
│               ├── splendor_players_card.dart
│               ├── splendor_selectable_gem_token.dart
│               ├── splendor_token_pool_card.dart
│               └── splendor_turn_header.dart
├── services/
│   └── splendor/
└── shared/
    ├── network/
    │   └── api_client.dart
    ├── widgets/
    │   └── mobile_viewport.dart
    └── utils/
```

说明：

- `main.dart`：Flutter 进程入口，只做启动前配置和挂载 App。
- `api/`：全项目 API 调用统一目录，按接口域拆文件，但不放进页面或模块子目录。
- `app/`：App 级配置，包括 App 外壳、路由、主题和颜色表。
- `models/`：全项目数据模型统一目录，按接口域拆文件，但不放进页面或模块子目录。
- `pages/`：页面、页面 Controller、页面内部组件，按页面或游戏拆分。
- `services/`：业务服务、规则服务、固定数据、状态推进逻辑。
- `shared/`：确认跨页面或跨游戏复用的网络、widget 和工具。

`pages/splendor/`、`services/splendor/` 是后续璀璨宝石页面、Bot 自动推进和 AI 建议展示编排位置。API 调用仍放在 `api/`，数据模型仍放在 `models/`。

## 当前前端分层约定

当前采用偏 MVVM 的简洁分层：

- `Page/View`：只负责页面结构、用户交互入口和组合 widget，不直接拼接口地址，不写完整业务规则。
- `Controller/ViewModel`：放在页面域的 `controller/` 子目录，负责页面状态、加载状态、接口编排、提交后的状态刷新和页面提示。
- `Widget/Action Panel`：放在页面域的 `widgets/` 或 `actions/`，只做展示和局部交互；需要提交行动时向上回调。
- `API`：统一放在 `frontend/lib/api/`，负责请求路径、请求发送和响应模型转换。
- `Models`：统一放在 `frontend/lib/models/`，对齐后端接口和状态结构。
- `Services/UseCase`：当规则、本地机器人、AI 建议展示编排或跨页面流程变复杂时，放到 `frontend/lib/services/`，避免 controller 变成规则大杂烩。

当前阶段 controller 承担“页面状态 + 接口编排”是合理的；但购买规则、弃宝石规则、Bot 策略、AI 策略、本地状态推进等不应继续堆进 controller，出现明确复杂度后要抽到 `services/splendor/` 并补文档。

架构约束：

- API 调用文件统一放在 `frontend/lib/api/`。
- 数据模型统一放在 `frontend/lib/models/`。
- 不要创建 `pages/xxx/api`、`pages/xxx/models`、`services/xxx/models` 这类分散目录。
- 如果某个 API/model 文件过大，优先在 `api/` 或 `models/` 下拆同级文件，而不是移动到模块目录。
- 页面 controller 必须放在对应页面域的 `controller/` 子目录，不与页面 UI 文件平级。

备注要求：

- 新增或修改 API 文件、API 方法、model 文件、核心 model 类、页面组件、widget、公共功能方法、核心业务方法时，必须有最基本的备注信息。
- 备注至少说明“这个东西做什么”，必要时补充输入、输出、对应接口或使用场景。
- 对外公开的类和方法优先用 `///` 文档注释；文件顶部或私有局部逻辑可用普通注释。
- 工具类、公共封装方法、Controller 中声明的每一个方法都必须有基本注释；私有方法也要说明职责，至少写清楚“做什么”和“什么场景会调用”。
- 注释要帮助阅读，不写空话。例如不要写“返回数据”“设置属性”，应写“创建本地同屏璀璨宝石对局并返回后端 GameState 快照”。
- 如果一个文件只是 barrel export，也要注明它导出了哪些模型组、什么时候该 import 它。

### `frontend/lib/api/api_config.dart`

职责：

- 统一维护 API 基础配置。
- 当前提供 `ApiConfig.defaultBaseUrl`。

核心类：

- `ApiConfig`

核心成员：

- `defaultBaseUrl`：默认后端地址，支持通过 `--dart-define=API_BASE_URL=...` 覆盖。

用法：

```dart
final apiClient = ApiClient(baseUrl: ApiConfig.defaultBaseUrl);
```

真机联调：

- Android/iOS 真机不能使用电脑本机的 `127.0.0.1` 访问后端。
- 后端服务监听 `0.0.0.0:3000` 时，真机应使用电脑局域网 IP，例如 `http://192.168.110.137:3000`。
- 如局域网 IP 变化，运行 Flutter 时传入：

```text
--dart-define=API_BASE_URL=http://你的电脑局域网IP:3000
```

### `frontend/lib/api/api_paths.dart`

职责：

- 统一维护 API path 字符串。
- 负责拼接带路径参数的接口地址。
- 让接口路径集中可查，同时让 `SplendorApi` 继续封装具体请求方法。

核心类：

- `ApiPaths`

核心成员和方法：

- `health`：`/health`。
- `splendorCatalog`：`/api/splendor/catalog`。
- `splendorSessions`：`/api/splendor/sessions`。
- `splendorSession(String sessionId)`：单局对局详情路径。
- `splendorLegalActions(String sessionId)`：当前合法行动路径。
- `splendorActions(String sessionId)`：提交行动和行动历史路径。
- `splendorBotAct(String sessionId)`：V2 当前 Bot 玩家自动行动路径，对应 `POST /api/splendor/sessions/:sessionId/bot/act`。
- `splendorAiDecision(String sessionId)`：V2 AI 建议 / AI 执行路径，计划对应 `POST /api/splendor/sessions/:sessionId/ai/decide`。
- `splendorAiStream(String sessionId)`：V2 AI 流式建议路径，对应 `POST /api/splendor/sessions/:sessionId/ai/stream`。

用法：

```dart
final path = ApiPaths.splendorActions(sessionId);
```

维护规则：

- 新增接口时先在 `ApiPaths` 登记 path。
- API 调用方法从 `ApiPaths` 取 path，不在方法里直接写字符串。

### `frontend/lib/api/splendor_api.dart`

职责：

- 统一封装璀璨宝石 V1 后端接口。
- 不写 UI 状态，不写页面交互，不写游戏规则。
- 通过 `ApiClient` 发请求，并把响应转成 `models/splendor_models.dart` 中的数据模型。

核心类：

- `SplendorApi`

核心方法：

- `health()`：调用 `GET /health`。
- `getCatalog()`：调用 `GET /api/splendor/catalog`。
- `createSession(SplendorCreateSessionInput input)`：调用 `POST /api/splendor/sessions`。
- `getSession(String sessionId)`：调用 `GET /api/splendor/sessions/:sessionId`。
- `getLegalActions(String sessionId)`：调用 `GET /api/splendor/sessions/:sessionId/legal-actions`。
- `submitAction(String sessionId, SplendorSubmitActionInput input)`：调用 `POST /api/splendor/sessions/:sessionId/actions`。
- `getActions(String sessionId)`：调用 `GET /api/splendor/sessions/:sessionId/actions`。
- `actBot(String sessionId)`：V2 调用 `POST /api/splendor/sessions/:sessionId/bot/act`，让当前 Bot 玩家由后端选择并执行一个合法行动。
- `requestAiAdvice(String sessionId)`：V2 调用 `POST /api/splendor/sessions/:sessionId/ai/decide` 获取结构化 AI 建议；只做请求和模型转换，不直接执行行动。
- `requestAiAdviceStream(String sessionId)`：V2 调用 `POST /api/splendor/sessions/:sessionId/ai/stream` 获取 SSE 流式建议事件；事件包含 progress、delta、result 和 done，result 会携带最终结构化建议。
- `_streamLog(String message)`：AI 流式接口专用日志，输出原始 chunk、SSE block 和解析后的业务事件，日志前缀为 `splendor.ai.stream`。
- `_errorFromDioException(DioException error)`：把流式请求中的 Dio 网络异常转换成统一 `ApiError`；网络中断类错误会返回 `NETWORK_INTERRUPTED` 等稳定错误码。
- `requestAiAdviceStream(String sessionId)`：流式读取阶段如果出现非 Dio 的底层 stream 异常，会统一转成 `AI_STREAM_READ_FAILED`，避免断网被误判为普通流式失败。

用法：

```dart
final splendorApi = SplendorApi();
final catalog = await splendorApi.getCatalog();
```

维护规则：

- 页面和 Controller 不要直接拼 URL。
- 接口路径统一从 `ApiPaths` 读取。
- 璀璨宝石相关后端接口优先补到 `SplendorApi`。
- 如果后端错误返回 `error.code/message`，由 API 层转换为 `ApiException`。
- AI 建议接口也放在 `SplendorApi`，不要在页面里直接拼 AI 接口地址。

## 文件职责

### `frontend/lib/models/api_models.dart`

职责：

- 统一维护通用 API 错误模型。

核心类：

- `ApiError`：后端错误结构，包含 `code` 和 `message`。
- `ApiException`：API 层抛出的统一异常。

用法：

```dart
try {
  await splendorApi.getCatalog();
} on ApiException catch (error) {
  // error.error.code / error.error.message
}
```

### `frontend/lib/models/splendor_base_models.dart`

职责：

- 维护璀璨宝石模型共用基础类型。
- 包含枚举、宝石集合、JSON 辅助解析方法。

核心模型：

- `JsonMap`
- `SplendorPlayerType`
- `SplendorSessionStatus`
- `SplendorActionType`
- `SplendorTokenSet`
- `SplendorGemSet`

### `frontend/lib/models/splendor_catalog_models.dart`

职责：

- 对齐 `GET /api/splendor/catalog`。
- 维护固定 catalog 响应模型。

核心模型：

- `SplendorCatalogResponse`
- `SplendorCard`
- `SplendorNoble`

### `frontend/lib/models/splendor_state_models.dart`

职责：

- 维护后端 `SplendorGameState` JSON 快照模型。
- 被 session、action、legal-actions 等响应复用。

核心模型：

- `SplendorGameState`
- `SplendorPlayerState`
- `SplendorPendingAction`
- `SplendorCardArea`
- `SplendorFinalRound`

### `frontend/lib/models/splendor_session_models.dart`

职责：

- 对齐创建对局和获取对局接口。

核心模型：

- `SplendorCreateSessionInput`
- `SplendorCreatePlayerInput`
- `SplendorSessionResponse`
- `SplendorSession`
- `SplendorSeatPlayer`

### `frontend/lib/models/splendor_action_models.dart`

职责：

- 对齐合法行动、提交行动、行动历史接口。

核心模型：

- `SplendorAction`
- `SplendorSubmitActionInput`
- `SplendorLegalActionsResponse`
- `SplendorLegalAction`
- `SplendorSubmitActionResponse`
- `SplendorActionRecord`
- `SplendorBotDecision`
- `SplendorBotActionResponse`
- `SplendorAiAdviceDecision`
- `SplendorAiAdviceResponse`
- `SplendorAiAdviceStreamEvent`
- `SplendorActionsResponse`

### `frontend/lib/models/splendor_models.dart`

职责：

- 作为璀璨宝石模型 barrel export。
- 调用方需要多个模型组时，可以统一 import 这个文件。
- 调用方只需要一个模型组时，也可以 import 对应拆分文件。

核心模型：

- 导出 `splendor_base_models.dart`。
- 导出 `splendor_catalog_models.dart`。
- 导出 `splendor_state_models.dart`。
- 导出 `splendor_session_models.dart`。
- 导出 `splendor_action_models.dart`。

用法：

```dart
final state = SplendorGameState.fromJson(json);
final action = SplendorAction.takeTokens(
  const SplendorTokenSet(white: 1, blue: 1, green: 1),
);
```

维护规则：

- 后端响应字段变化时，优先更新这里。
- 不要在页面中临时解析 `Map<String, dynamic>`。
- 不要在模块目录下创建重复的 Splendor model。
- 如果单个模型文件过大，在 `frontend/lib/models/` 下继续拆同级文件，不移动到模块目录。

### `frontend/lib/main.dart`

职责：

- 调用 `WidgetsFlutterBinding.ensureInitialized()` 初始化 Flutter 绑定。
- 使用 `SystemChrome.setPreferredOrientations` 限制竖屏。
- 使用 `SystemChrome.setSystemUIOverlayStyle` 配置状态栏和底部导航栏样式。
- 调用 `runApp(const BoardGameAiApp())` 启动 App。

用法：

- 不在这里写页面逻辑、业务逻辑、路由表或规则判断。
- 需要新增全局启动前配置时，优先放在这里。
- 如果配置变多，再拆到 `app/bootstrap.dart`，并同步更新本文档。

核心方法：

- `main()`：App 启动入口。当前是 `Future<void>`，因为竖屏配置需要 `await`。

### `frontend/lib/app/app.dart`

职责：

- 定义 App 根组件 `BoardGameAiApp`。
- 初始化 `ScreenUtilInit`，统一设计稿尺寸。
- 创建 `GetMaterialApp`，接入标题、主题、初始路由、路由表。
- 通过 `builder` 包裹 `MobileViewport`，限制大屏下的手机内容宽度。

核心类：

- `BoardGameAiApp extends StatelessWidget`

核心方法：

- `build(BuildContext context)`：返回全局 App 外壳。

关键配置：

- `designSize: Size(393, 852)`：当前按常见手机宽度设计。
- `minTextAdapt: true`：文本按设备适配。
- `splitScreenMode: true`：允许分屏场景下适配。
- `initialRoute: AppRoutes.index`：默认进入首页。
- `getPages: AppRoutes.pages`：统一从路由表读取页面。
- `builder` 中使用 `MobileViewport`：让平板或桌面宽屏下仍保持手机布局。

用法：

```dart
runApp(const BoardGameAiApp());
```

注意：

- 全局依赖注入、全局 middleware、国际化等 App 级能力，后续优先放在这里或 `app/` 下新增文件。
- 不要在这里写某个具体游戏的规则或状态。

### `frontend/lib/app/app_colors.dart`

职责：

- 统一维护 App 颜色常量。
- 为 `AppTheme`、页面、组件提供稳定的颜色入口。
- 避免同一颜色在多个文件里重复写十六进制值。

核心类：

- `AppColors`

核心成员：

- `primary`：主色。
- `onPrimary`：主色上的文字或图标颜色。
- `secondary`：辅助色。
- `onSecondary`：辅助色上的文字或图标颜色。
- `error`：错误色。
- `onError`：错误色上的文字或图标颜色。
- `surface`：页面背景色。
- `onSurface`：页面背景上的主要文字颜色。
- `card`：卡片背景色。
- `border`：默认边框色。
- `splendorBlue`：当前首页 AI 状态行使用的蓝色。

核心方法：

- `withOpacity(Color color, double opacity)`：统一用 `Color.withValues(alpha: opacity)` 处理透明度，避免到处直接写不同形式的透明度代码。

用法：

```dart
color: AppColors.primary
```

```dart
color: AppColors.withOpacity(AppColors.primary, 0.12)
```

维护规则：

- 新增全局颜色时，优先加到 `AppColors`。
- 页面内优先使用 `Theme.of(context).colorScheme`。如果颜色不是主题语义色，再从 `AppColors` 取。
- 不要在页面或组件中散落重复的 `Color(0x...)`。
- 如果某个颜色只在一个局部装饰中使用，可以先留在局部；出现复用或语义固定后再迁移到 `AppColors`。
- 不要弃用 `AppColors` 直接改回硬编码颜色；如要替换颜色体系，先更新本文档说明。

### `frontend/lib/app/routes.dart`

职责：

- 统一维护路由名称和 `GetPage` 路由表。
- 避免页面之间硬编码字符串路径。

核心类：

- `AppRoutes`

当前路由：

| 常量 | 路径 | 页面 |
| --- | --- | --- |
| `AppRoutes.index` | `/` | `IndexPage` |
| `AppRoutes.splendorCreateSession` | `/splendor/create-session` | `SplendorCreateSessionPage` |
| `AppRoutes.splendorTable` | `/splendor/table` | `SplendorTablePage` |

核心成员：

- `static const index = '/'`：首页路径。
- `static const splendorCreateSession = '/splendor/create-session'`：璀璨宝石创建对局页路径。
- `static const splendorTable = '/splendor/table'`：璀璨宝石对局桌面页路径。
- `static final pages = <GetPage>[...]`：GetX 路由表。

用法：

```dart
Get.toNamed(AppRoutes.index);
```

新增页面时：

1. 在页面目录创建页面文件。
2. 在 `routes.dart` 增加路由常量。
3. 在 `pages` 列表增加 `GetPage`。
4. 更新本文档的“当前路由”表。

### `frontend/lib/app/theme.dart`

职责：

- 统一维护 App 全局视觉主题。
- 当前只定义浅色主题 `AppTheme.light`。

核心类：

- `AppTheme`

核心成员：

- `static ThemeData get light`：返回全局浅色 `ThemeData`。

当前主题约定：

- 使用 Material 3。
- 主色：`Color(0xFF245B46)`。
- 辅色：`Color(0xFFC8893A)`。
- 页面背景：`Color(0xFFF7F5EF)`。
- `Card` 圆角固定为 8。
- `FilledButton` / `OutlinedButton` 最小高度 48，圆角 8。

用法：

```dart
theme: AppTheme.light
```

注意：

- 页面内优先使用 `Theme.of(context).colorScheme` 和 `Theme.of(context).textTheme`。
- 不要在多个页面里重复定义同一套颜色和按钮样式。
- 新增全局颜色、组件主题或字体配置时，写在这里并更新本文档。
- `theme.dart` 的颜色来源应优先使用 `AppColors`。

### `frontend/lib/pages/index/index_page.dart`

职责：

- App 首页。
- 展示产品名称、当前第一个桌游入口“璀璨宝石”、当前阶段状态。
- 当前只做入口占位，不创建真实对局。

核心类：

- `IndexPage extends StatelessWidget`：首页对外页面类。

页面内部私有组件：

- `_Header`：首页顶部品牌区域。
- `_GameEntryCard`：璀璨宝石入口卡片，左侧展示竖版 `images/splendor/bg.webp` 封面图，右侧展示游戏信息，下方展示开始按钮，并接收 `onStart` 回调。
- `_ProjectStagePanel`：当前开发阶段状态展示。
- `_StageRow`：阶段状态行。
- `_InfoChip`：入口卡片内的小标签。

核心方法：

- `IndexPage.build(BuildContext context)`：构建首页滚动布局。
- `_GameEntryCard.onStart`：点击“开始对局”后的回调入口。当前跳转到 `AppRoutes.splendorCreateSession`。

用法：

```dart
GetPage(
  name: AppRoutes.index,
  page: () => const IndexPage(),
)
```

维护规则：

- 首页只负责入口与概览。
- 创建对局、选择玩家人数、玩家名称等流程应拆到 `pages/splendor/` 下的页面。
- `_InfoChip` 等当前只在首页使用，暂不抽到 `shared/`。如果其他页面也需要，再抽成公共 widget，并记录到本文档“可复用 Widget”。

### `frontend/lib/pages/splendor/splendor_create_session_page.dart`

职责：

- 璀璨宝石创建对局页。
- 收集玩家人数、玩家名称和玩家类型。
- 调用 `SplendorApi.createSession` 创建本地同屏对局。
- 创建成功后跳转到 `AppRoutes.splendorTable`，并通过 `Get.arguments` 传递 `SplendorSessionResponse`。

核心类：

- `SplendorCreateSessionPage extends StatefulWidget`

页面内部私有组件：

- `_PlayerInputRow`：单个座位输入行，包含玩家名称输入和真人/Bot 分段选择。

核心方法：

- 创建逻辑由 `SplendorCreateSessionController.createSession()` 负责。

用法：

```dart
Get.toNamed(AppRoutes.splendorCreateSession);
```

维护规则：

- 本页只负责创建对局表单和接口编排，不写璀璨宝石规则判断。
- V2 已支持 `SplendorPlayerType.human` 和 `SplendorPlayerType.bot`；Bot 默认 `botLevel` 为 `balanced`。
- 新增创建参数时，必须先确认后端接口和需求，再更新 `SplendorCreateSessionInput` 与本文档。

### `frontend/lib/pages/splendor/create_session/controller/splendor_create_session_controller.dart`

职责：

- 管理创建对局页的表单状态。
- 维护玩家人数、玩家名称输入框、玩家类型和提交状态。
- 调用 `SplendorApi.createSession` 创建对局。
- 创建成功后跳转到 `AppRoutes.splendorTable`。
- 作为创建对局页的 ViewModel，不直接写页面 UI。

核心类：

- `SplendorCreateSessionController extends GetxController`

核心成员：

- `playerCount`：当前玩家人数。
- `isSubmitting`：是否正在创建对局。
- `nameControllers`：固定 4 个输入框控制器，覆盖 2-4 人。
- `playerTypes`：固定 4 个玩家类型状态，覆盖 2-4 人。

核心方法：

- `setPlayerCount(int value)`：切换玩家人数。
- `setPlayerType(int index, SplendorPlayerType type)`：设置某个座位是真人或 Bot。
- `createSession()`：校验名称、提交创建对局请求、处理成功跳转和错误提示。

用法：

```dart
final controller = Get.put(SplendorCreateSessionController());
```

维护规则：

- 表单状态优先放在 controller，不要再堆在页面 build 里。
- 创建参数发生变化时，先确认后端接口，再改 controller。
- 复杂业务流程不要继续堆在 controller；出现复用或规则编排需求时抽到 `services/`。

### `frontend/lib/pages/splendor/create_session/player_count_selector.dart`

职责：

- 创建对局页里的 2-4 人选择控件。
- 只负责人数切换，不承载其它表单逻辑。

核心类：

- `PlayerCountSelector extends StatelessWidget`

核心方法：

- `build(BuildContext context)`：渲染 `SegmentedButton<int>`。

用法：

```dart
PlayerCountSelector(
  playerCount: controller.playerCount.value,
  onChanged: controller.setPlayerCount,
)
```

维护规则：

- 这个控件只属于创建对局页，不要提前抽到 `shared/`。

### `frontend/lib/pages/splendor/splendor_table_page.dart`

职责：

- 璀璨宝石对局桌面页。
- 接收创建对局返回的 `SplendorSessionResponse`。
- 使用紧凑棋盘式布局展示对手摘要、公共宝石池、市场卡牌详情、贵族详情、当前玩家和行动区。
- 提供刷新按钮，通过 `SplendorApi.getSession` 重新拉取当前状态。
- 当前玩家摘要固定展示玩家手里的各色宝石、分数、永久 bonus 和预留数量。
- 负责打开市场发展卡行动面板，并把后端合法行动提交给控制器。
- 通过行动历史中 `reserve_card source: deck` 的前后状态差异，识别其他玩家从牌堆盲抽的预留卡，并在对手详情中隐藏这些卡面。
- 如果当前行动玩家是 Bot，页面展示 Bot 思考状态，实际自动行动由 `SplendorTableController` 调用后端完成。
- 如果当前行动玩家是真人，页面展示“AI 建议”按钮，点击后请求后端建议并打开底部策略面板。

核心类：

- `SplendorTablePage extends StatefulWidget`

页面内部私有组件：

- `_OpponentStrip`：顶部对手摘要条。
- `_CompactOpponentCard`：单个对手的紧凑摘要。
- `_TurnPrompt`：当前回合提示；如果当前玩家是 Bot，会显示等待自动行动或思考中；如果存在 `pendingAction`，会提示先弃宝石或先选贵族。
- `_AiAdviceButton`：真人当前回合的 AI 建议入口，只负责加载态和点击回调。
- `_EmptySessionView`：路由参数缺失时的空状态。
- `_hiddenReservedCardIdsByPlayer(...)`：根据行动历史识别每位玩家需要隐藏的盲抽预留卡；历史加载中时保守隐藏全部对手预留卡。

核心方法：

- `_showCardActions(SplendorCard card)`：打开被点选市场卡的购买/预留行动面板，面板只匹配后端返回的合法行动。
- `_showAiAdviceSheet()`：请求 `SplendorTableController.requestAiAdvice()`，成功后打开 `SplendorAiAdvicePanel` 展示结构化建议。

用法：

```dart
Get.offNamed(AppRoutes.splendorTable, arguments: sessionResponse);
```

维护规则：

- 市场和贵族必须优先展示 catalog 信息；只有 catalog 缺失时才用 ID 兜底。
- 行动按钮应优先基于 `SplendorApi.getLegalActions` 返回内容展示。
- 提交行动后使用 `SplendorApi.submitAction` 返回的新 `state` 刷新页面。
- Bot 行动后使用 `SplendorApi.actBot` 返回的新 `state` 刷新页面。
- AI 建议只展示推荐内容，不自动执行行动；采纳建议要等后续明确交互再开发。
- 本页不重新实现后端已有的规则判断，只做必要的 UI 禁用和提示。
- 页面只拼接布局，接口请求和状态变更放在 `SplendorTableController`。

### `frontend/lib/pages/splendor/table/actions/card_actions_sheet.dart`

职责：

- 发展卡购买/预留行动面板。
- 展示被点选卡牌的等级、分数、奖励颜色和购买费用。
- 根据 `source` 和后端合法行动匹配当前卡是否能执行 `buy_card` 或 `reserve_card`。
- 提交时直接回传匹配到的 `SplendorLegalAction`，不在前端自行计算购买或预留规则。

核心类：

- `CardActionsSheet`

核心方法：

- `CardActionsSheet.show(...)`：打开 bottom sheet，传入卡牌、合法行动列表、提交状态和提交回调。

匹配规则：

- 购买市场卡：`action.type == buy_card`、`payload.source == market`、`payload.cardId == card.id`。
- 预留市场卡：`action.type == reserve_card`、`payload.source == market`、`payload.cardId == card.id`。
- 购买预留卡：`action.type == buy_card`、`payload.source == reserved`、`payload.cardId == card.id`。

用法：

```dart
await CardActionsSheet.show(
  context: context,
  card: card,
  source: 'reserved',
  actions: controller.legalActions.value?.actions ?? const [],
  isSubmitting: controller.isSubmittingAction.value,
  onSubmit: controller.submitLegalAction,
);
```

维护规则：

- 面板只做合法行动匹配，不推导费用、折扣、黄金支付或预留上限。
- 如果后端新增牌堆预留、预留区购买等入口，应新增明确的 source 匹配分支，不要复用市场卡匹配逻辑。

### `frontend/lib/pages/splendor/table/controller/splendor_table_controller.dart`

职责：

- 管理桌面页的对局状态、catalog 和合法行动。
- 调用 `getCatalog`、`getSession`、`getLegalActions`、`getActions`、`submitAction` 和 `actBot`。
- 维护刷新、加载、提交和 Bot 自动行动状态。
- 作为桌面页的 ViewModel，负责页面状态和接口编排，不承载完整规则判断。

核心类：

- `SplendorTableController extends GetxController`

核心成员：

- `sessionResponse`：当前对局快照。
- `catalog`：固定图鉴。
- `legalActions`：当前合法行动。
- `actionHistory`：当前对局行动历史记录。
- `isRefreshing`：对局刷新状态。
- `isLoadingCatalog`：图鉴加载状态。
- `isLoadingLegalActions`：合法行动加载状态。
- `isLoadingActionHistory`：行动历史加载状态。
- `isSubmittingAction`：行动提交状态。
- `isActingBot`：Bot 自动行动状态。
- `isLoadingAiAdvice`：AI 建议请求状态。
- `aiAdvice`：最近一次 AI 建议响应，供底部策略面板展示。
- `aiAdviceStreamLines`：AI 流式建议逐段文本，供底部策略面板展示实时分析过程。

核心方法：

- `initialize(SplendorSessionResponse? initialSessionResponse)`：接收进入桌面页时的初始对局。
- `loadCatalog()`：拉取 catalog。
- `refreshSession()`：拉取当前对局快照。
- `loadLegalActions()`：拉取当前合法行动。
- `loadActionHistory()`：拉取当前对局行动历史。
- `submitLegalAction(SplendorLegalAction legalAction)`：提交后端返回的合法行动。
- `actCurrentBot()`：调用后端 Bot 自动行动接口，更新状态并提示 Bot 决策原因。
- `requestAiAdvice()`：为当前真人玩家请求 AI 建议；优先走流式接口，失败时回退非流式接口，不执行推荐行动。
- `_requestAiAdviceStreamWithRetry(String sessionId)`：AI 流式请求网络中断时保留已输出文本并自动重试，重连后明确提示“以下为重新生成内容”；默认最多重试 3 次。
- `_consumeAiAdviceStream(String sessionId)`：消费一次 AI SSE 流，把 `delta` 文本和 `result` 结构化建议分别写入页面状态。
- `_aiAdviceRetryDelay(int attempt)`：AI 流式自动重试的指数退避间隔，当前依次为 1、2、4 秒。
- `_requestAiAdviceFallback(String sessionId)`：AI 流式接口失败后的非流式兜底请求，保证建议功能不中断。
- `_isNetworkInterrupted(ApiException error)`：识别 AI 流式请求中的网络中断、读取失败、取消和证书异常；这类错误不再继续 fallback，而是在面板中提示用户重试或自动重连。
- `_appendAiAdviceStreamText(String text, { required bool appendToLastLine })`：把流式文本追加到实时分析展示区；模型 delta 默认合并到上一行，避免一个字一个字变成多行。
- `_AiAdviceStreamDisplayFilter`：过滤模型原生流中的 `<FINAL_JSON>`、半截 `<FINAL_JSON`、JSON 片段和 markdown 标识，只把自然语言分析交给 UI 展示。
- `_scheduleBotAutoAction()`：当前玩家是 Bot 时延迟触发自动行动；连续 Bot 会在成功行动后继续推进。
- `_showAwardedNobleMessage(...)`：提交行动后对比玩家前后贵族列表，如果本回合自动获得贵族，则显示底部提示。
- `_nobleById(String nobleId)`：从已加载 catalog 中查找贵族，仅用于获得贵族提示文案。
- `_isHeuristicFallback(SplendorAiAdviceResponse response)`：根据建议理由判断本次是否是模型失败后的本地启发式 fallback，仅用于前端日志。
- `_showMessage(String message)`：桌面页轻量提示统一显示在顶部，避免底部 snackbar 挡住玩家操作区。

用法：

```dart
final controller = Get.put(SplendorTableController());
controller.initialize(sessionResponse);
```

维护规则：

- 桌面页所有接口编排优先放到 controller，不要再写进页面 build。
- `legalActions` 必须以后端为准，前端不自己推导合法性。
- 行动历史以后端 `game_actions` 为准；自动贵族事件由后端记录为 `noble_visit`，前端只负责翻译展示。
- 贵族获得由后端在回合收尾自动结算；前端只根据提交行动前后的 `player.nobles` 差异提示结果，不提供手动选择贵族入口。
- Bot 决策由后端 `bot-advisor.ts` 负责，前端 controller 只做自动触发和状态刷新，不在前端复刻策略。
- AI 建议接口由 `SplendorApi.requestAiAdvice` / `requestAiAdviceStream` 统一封装，页面和 controller 不直接拼路径。
- AI 建议请求开始、成功和失败都会在 Flutter 日志中以 `splendor.ai` / `splendor.api` 分类输出，方便真机调试模型是否真实返回。
- 弃宝石、AI 建议多步编排或本地规则服务等复杂流程出现后，优先抽到 `services/splendor/`。

### `frontend/lib/pages/splendor/table/splendor_catalog_lookup.dart`

职责：

- 把 catalog 响应整理成卡牌 ID 和贵族 ID 的索引。
- 供桌面页把 GameState 中的 ID 映射成可读卡牌详情。

核心类：

- `SplendorCatalogLookup`

核心成员：

- `cardsById`
- `noblesById`

用法：

```dart
final lookup = SplendorCatalogLookup(controller.catalog.value);
```

维护规则：

- 只做索引，不做规则判断。

### `frontend/lib/pages/splendor/table/actions/legal_actions_panel.dart`

职责：

- 桌面页的合法行动面板。
- 展示当前行动状态，并在 `pendingAction: discard_tokens` 时承载弃宝石操作入口。
- 贵族卡不在这里处理；后端会在玩家可选行动和必要弃宝石完成后自动判断是否获得 1 张贵族。

核心类：

- `LegalActionsPanel`

核心方法：

- `build(BuildContext context)`：根据合法行动、当前玩家和加载状态展示行动面板，必要时切换到 `DiscardTokensPanel`。

### `frontend/lib/pages/splendor/table/actions/discard_tokens_panel.dart`

职责：

- 弃宝石行动面板。
- 当后端返回 `pendingAction: discard_tokens` 时，允许用户点击圆形宝石选择要弃掉的数量。
- 只匹配后端返回的合法弃宝石行动，不自行推导规则。

核心类：

- `DiscardTokensPanel`

核心方法：

- `build(BuildContext context)`：展示当前玩家宝石、选择状态和提交按钮。

### `frontend/lib/pages/splendor/table/widgets/splendor_selectable_gem_token.dart`

职责：

- 可点击或静态展示的圆形宝石 token。
- 拿宝石和弃宝石面板共用。

核心类：

- `SplendorSelectableGemToken`

适合复用场景：

- 任何需要展示“颜色圆点 + 数量 + 已选数量”的桌面宝石交互。

### `frontend/lib/pages/splendor/table/actions/take_tokens_panel.dart`

职责：

- 拿宝石行动面板。
- 用户通过点击圆形宝石形成选择。
- 用后端返回的合法 `take_tokens` 行动判断当前选择是否可提交。
- 点击式拿宝石操作实际放在公共宝石池区域。
- 公共宝石区不自行判断必须拿 3 个；当后端返回“只剩 1-2 种普通宝石可少拿”的合法行动时，面板按合法行动列表允许提交。
- 当当前选择已经是另一个合法组合时，继续点击其他颜色会尝试切换到兼容的合法组合，例如 `黑2` 可以切换成 `红1黑1`。
- 当当前没有合法拿宝石行动时，例如正在处理弃宝石 pendingAction，公共宝石区仍然展示公共池数量，只禁用拿取交互。

核心类：

- `TakeTokensPanel`

核心方法：

- `build(BuildContext context)`：把合法拿宝石行动渲染成可点击宝石选择器。

维护规则：

- 这里不自己推完整规则，只用后端合法列表判断当前选择能否继续或提交。

### `frontend/lib/pages/splendor/table/widgets/splendor_info_card.dart`

职责：

- 桌面页内部通用信息卡。
- 统一标题、内边距和卡片样式。

核心类：

- `SplendorInfoCard`

### `frontend/lib/pages/splendor/table/widgets/splendor_market_card.dart`

职责：

- 桌面页市场卡牌区域。
- 把市场卡牌 ID 映射成真实卡面。
- 向上抛出用户点选的发展卡，不直接处理购买或预留提交。
- 向每个等级的 `SplendorMarketSection` 传入合法行动和提交回调，用于展示牌堆盲抽预留按钮。

核心类：

- `SplendorMarketCard`

核心参数：

- `onCardSelected`：用户点选市场卡后的回调，通常由 `SplendorTablePage` 打开 `CardActionsSheet`。
- `legalActions`：后端返回的合法行动，用于匹配 `reserve_card source: deck`。
- `isSubmitting`：行动提交中状态。
- `onSubmit`：提交匹配到的合法行动。

### `frontend/lib/pages/splendor/table/widgets/splendor_noble_card.dart`

职责：

- 桌面页贵族区域。
- 把贵族 ID 映射成真实贵族需求。

核心类：

- `SplendorNobleCard`

### `frontend/lib/pages/splendor/table/widgets/splendor_players_card.dart`

职责：

- 桌面页玩家摘要区域。
- 通过 `cardsById` 向每个 `SplendorPlayerSummaryCard` 传递发展卡索引，保证玩家资产展示一致。

核心类：

- `SplendorPlayersCard`

### `frontend/lib/pages/splendor/table/widgets/splendor_turn_header.dart`

职责：

- 桌面页当前回合摘要。

核心类：

- `SplendorTurnHeader`

### `frontend/lib/pages/splendor/table/widgets/splendor_token_pool_card.dart`

职责：

- 桌面页公共 token 池展示。

核心类：

- `SplendorTokenPoolCard`

### `frontend/lib/pages/splendor/table/widgets/splendor_market_section.dart`

职责：

- 桌面页单个等级的市场卡牌区域。
- 把当前等级市场卡 ID 映射成 `SplendorDevelopmentCardTile`，并传递卡牌点击回调。
- 在等级标题旁展示牌堆盲抽预留按钮；按钮只匹配后端返回的 `reserve_card`、`source: deck`、`level` 对应行动，不在前端推导规则。

核心类：

- `SplendorMarketSection`

核心参数：

- `level`：当前市场等级，用于匹配盲抽预留行动。
- `actions`：当前合法行动列表。
- `isSubmitting`：行动提交中状态。
- `onSubmit`：提交匹配到的盲抽预留行动。

### `frontend/lib/pages/splendor/table/widgets/splendor_development_card_tile.dart`

职责：

- 桌面页发展卡简化卡面。
- 支持可选点击回调，供市场卡选择后打开购买/预留面板。

核心类：

- `SplendorDevelopmentCardTile`
- 固定高度发展卡卡面，避免因费用换行造成高度不一致。

核心参数：

- `onTap`：可选点击回调；为空时只展示卡面，不显示可交互边框。

### `frontend/lib/pages/splendor/table/widgets/splendor_noble_tile.dart`

职责：

- 桌面页贵族简化卡面。
- 只展示场上贵族的分数和需求；贵族获得由后端自动结算，不提供点击交互。

核心类：

- `SplendorNobleTile`

### `frontend/lib/pages/splendor/table/widgets/splendor_action_history_panel.dart`

职责：

- 桌面页行动历史面板。
- 把后端 `GameAction` 记录转成中文文案，展示拿宝石、购买、预留、弃宝石和自动获得贵族事件。
- 使用紧凑列表展示标题、描述和回合序号，避免游戏后期历史过长时难以扫读。
- 面板内按时间倒序展示，最新操作在最上方；后端和 controller 仍保持原始正序列表，避免影响其它状态推断。

核心类：

- `SplendorActionHistoryPanel`

核心参数：

- `actions`：后端返回的历史行动记录。
- `players`：当前玩家列表，用于把 `playerIndex` 转成玩家名。
- `cardsById`：发展卡 catalog 索引。
- `noblesById`：贵族 catalog 索引。
- `isLoading`：行动历史加载状态。
- `scrollController`：可选滚动控制器，bottom sheet 内传入以协调拖拽滚动。

### `frontend/lib/pages/splendor/table/widgets/splendor_ai_advice_panel.dart`

职责：

- 真人玩家点击“AI 建议”后展示结构化策略建议。
- 面板打开时不自动请求接口；优先展示 controller 中保留的上一条建议。
- 用户点击面板内“获取 AI 建议 / 重新获取建议”按钮后，才调用后端 AI 建议接口。
- 支持展示 AI 流式接口逐段返回的实时分析文本。
- 生成中展示完整实时分析；生成完成且已有最终建议时，实时分析区域只保留最后 3 行摘要。
- 展示推荐结论、推荐行动、置信度、推荐理由、备选行动、对手威胁和风险提示。
- 第一版只读展示，不提供采纳建议或自动执行行动。

核心类：

- `SplendorAiAdvicePanel`
- `_RequestAdviceButton`
- `_StreamAdviceSection`
- `_EmptyAdviceState`

核心参数：

- `advice`：可空的 `SplendorAiAdviceResponse`，来自 controller 中缓存的最近一次 `SplendorApi.requestAiAdvice` 结果。
- `streamLines`：AI 流式接口逐段返回的文本列表，来自 controller 的 `aiAdviceStreamLines`。
- `isLoading`：当前是否正在生成 AI 建议，用于禁用面板内按钮和显示加载文案。
- `onRequestAdvice`：面板内请求建议按钮回调，由 controller 负责实际接口调用。
- `onClose`：关闭 bottom sheet 的回调。
- `scrollController`：可选滚动控制器，bottom sheet 内传入以协调拖拽滚动。

维护规则：

- 面板不直接持有 API；只通过 `onRequestAdvice` 通知 controller 请求接口，不直接提交行动。
- 生成期间 `isLoading=true` 时，面板内建议按钮必须禁用，避免重复请求模型。
- 关闭再打开 AI 建议面板时，应继续展示 controller 缓存的上一条建议，避免用户误关弹窗后看不到结果。
- 面板只展示后端已经校验过的推荐行动和解释。
- 后续流式输出、桌面高亮或“采纳建议”应在保持该面板只负责展示的前提下新增明确回调。

### `frontend/lib/pages/splendor/table/widgets/splendor_game_result_panel.dart`

职责：

- 桌面页终局状态和结果面板。
- 终局轮触发后展示“最后一轮”提示，说明谁达到 15 分以及本轮结束座位。
- 对局结束后展示获胜玩家和最终排行；排行规则与后端保持一致，先比分数，再比已购卡牌数量更少者优先。

核心类：

- `SplendorGameResultPanel`

核心参数：

- `state`：当前完整对局状态。

### `frontend/lib/pages/splendor/table/widgets/splendor_player_summary_card.dart`

职责：

- 桌面页单个玩家摘要。
- 当前玩家会直接展示手里宝石、五色永久宝石汇总和已购分数卡汇总。
- 当前玩家会直接展示预留卡；传入 `onReservedCardSelected` 后可点击预留卡打开购买面板。
- 通过 `cardsById` 把玩家已购卡牌 ID 映射成可读卡牌信息。
- Bot 玩家名称旁显示 `smart_toy` 图标，帮助区分真人和 Bot。

核心类：

- `SplendorPlayerSummaryCard`
- 当前玩家摘要会固定展示各色宝石圆点，方便直接看手牌资源。

### `frontend/lib/pages/splendor/table/widgets/splendor_player_assets_panel.dart`

职责：

- 玩家资产详情面板。
- 当前玩家直接在摘要卡下方复用它展示五色永久宝石汇总、已购分数卡和预留卡。
- 其他玩家点击顶部玩家面板后，在弹窗内复用它展示分数、永久宝石汇总、已购分数卡、预留卡数量和手里宝石；从牌堆盲抽的预留卡用隐藏占位展示，避免泄露隐藏信息。
- 永久宝石数量只在上方五色汇总展示；下方已购卡牌区域只展示分数卡，避免重复展示卡牌颜色。可见预留卡牌复用 `SplendorDevelopmentCardTile` 展示完整卡面，传入 `onReservedCardSelected` 时可点击。

核心类：

- `SplendorPlayerAssetsPanel`

核心参数：

- `player`：要展示的玩家状态。
- `cardsById`：发展卡 catalog 索引。
- `showTokens`：是否展示当前手里的 token，默认不展示。
- `showReservedCards`：是否展示预留卡牌详情，默认不展示。
- `hiddenReservedCardIds`：需要隐藏卡面的预留卡 ID；对手盲抽预留卡会传入这里。
- `onReservedCardSelected`：点击预留卡回调；为空时预留卡只展示。

### `frontend/lib/pages/splendor/table/widgets/splendor_gem_chip.dart`

职责：

- 桌面页宝石数量标签。

核心类：

- `SplendorGemChip`

### `frontend/lib/pages/splendor/table/widgets/splendor_cost_wrap.dart`

职责：

- 桌面页费用或需求集合展示。

核心类：

- `SplendorCostWrap`

### `frontend/lib/pages/splendor/table/widgets/splendor_cost_chip.dart`

职责：

- 桌面页单个颜色费用标签。

核心类：

- `SplendorCostChip`

### `frontend/lib/pages/splendor/table/splendor_card_style_helpers.dart`

职责：

- 桌面页卡牌样式辅助方法。
- 提供颜色、等级、文字可读性和缺失兜底组件。

核心类：

- `SplendorMissingCatalogTile`

核心方法：

- `nonZeroGemEntries(SplendorGemSet gems)`
- `levelLabel(int level)`
- `gemName(String colorKey)`
- `gemShortName(String colorKey)`
- `gemColor(String colorKey)`
- `readableTextColor(Color backgroundColor)`

### `frontend/lib/shared/widgets/mobile_viewport.dart`

职责：

- 在大屏、平板、桌面窗口中限制 App 内容最大宽度，保持手机端视觉和交互密度。

核心类：

- `MobileViewport extends StatelessWidget`

核心成员：

- `static const double maxPhoneWidth = 480`：手机内容最大宽度。
- `final Widget child`：需要限制宽度的子组件。

核心方法：

- `build(BuildContext context)`：使用 `ColoredBox + Center + ConstrainedBox` 包裹子组件。

用法：

```dart
MobileViewport(
  child: child,
)
```

当前使用位置：

- `BoardGameAiApp` 的 `GetMaterialApp.builder`。

注意：

- 这个 widget 是全局复用组件。
- 不要在每个页面单独重复写 `ConstrainedBox(maxWidth: 480)`。
- 如果后续需要平板专属布局，再在这个组件或新的布局组件中统一处理。

### `frontend/lib/shared/network/api_client.dart`

职责：

- 统一封装 Dio 网络请求。
- 提供全项目共享的 HTTP `get`、`post`、`put`、`delete` 方法。
- 提供 `postTextStream` 读取 UTF-8 文本流，当前用于 AI 建议 SSE。
- 统一配置 JSON 请求、JSON 响应、连接超时和接收超时。
- 提供 `setBearerToken` 管理 Authorization header。
- 统一通过 Dio interceptor 打印接口日志，使用 `debugPrint` 输出到 Flutter 控制台，包含请求路径、query、body、header、响应状态和响应数据。

核心类：

- `ApiClient`

构造参数：

- `dio`：可选，测试或特殊场景可注入自定义 Dio。
- `baseUrl`：可选，默认空字符串。当前不写死后端地址，避免在基础设施层提前绑定环境。
- `connectTimeout`：连接超时，默认 15 秒。
- `receiveTimeout`：接收超时，默认 190 秒；AI 建议接口最多等待后端 3 分钟模型返回，前端需要略长于后端超时，避免过早断开。

核心成员：

- `dio`：暴露底层 Dio，只在确实需要添加 interceptor 或处理特殊能力时使用。
- `authorizationHeader`：Authorization header 名称常量。
- `_logName`：网络日志分类名，当前为 `api.client`。
- `_maxLogLength`：单条日志最长输出长度，避免大响应刷屏。

核心方法：

- `setBearerToken(String? token)`：设置或清除 `Authorization: Bearer xxx`。
- `get<T>(String path, ...)`：发送 GET 请求。
- `post<T>(String path, ...)`：发送 POST 请求。
- `postTextStream(String path, ...)`：发送 POST 请求并读取文本流，适合 SSE 或其它逐段返回文本的接口；会打印 stream 响应头和每个原始文本 chunk。
- `put<T>(String path, ...)`：发送 PUT 请求。
- `delete<T>(String path, ...)`：发送 DELETE 请求。
- `_createLogInterceptor()`：创建统一请求日志拦截器；请求、响应和错误都会输出到 Flutter 控制台。
- `_writeLog(String message)`：统一使用 `debugPrint` 输出日志；不要用 `dart:developer.log` 替代，避免 IDE 普通运行窗口看不到网络日志。
- `_mergedHeaders(RequestOptions options)`：合并全局 header 和单次请求 header，供日志打印使用。
- `_maskHeaders(...)` / `_maskSecret(...)`：日志脱敏工具，当前会隐藏 `Authorization`。
- `_clipLog(String text)`：裁剪过长日志，避免图鉴、对局状态等大 JSON 把控制台刷满。

用法：

```dart
final apiClient = ApiClient(baseUrl: 'http://127.0.0.1:3000');
final response = await apiClient.get<Map<String, dynamic>>('/health');
```

```dart
apiClient.setBearerToken(token);
```

维护规则：

- 后续页面、Controller、业务 service 不要直接 `Dio()`。
- 新的接口服务应通过构造函数接收 `ApiClient`，方便测试和替换环境。
- 网络日志必须优先在 `ApiClient` 层维护，避免每个 API 方法重复写日志。
- 新增敏感 header 或敏感参数时，必须同步扩展 `_maskHeaders` 或新增脱敏逻辑。
- 如果要新增拦截器、错误转换、日志、重试、上传下载等通用能力，优先扩展 `ApiClient` 或围绕它新增文件，并同步更新本文档。
- 不要绕过 `ApiClient` 写一套新的网络封装；如确实需要替换网络层，先更新本文档说明原因和新用法。

## 当前可复用 Widget

### `MobileViewport`

文件：

```text
frontend/lib/shared/widgets/mobile_viewport.dart
```

用途：

- 全局限制手机 App 内容最大宽度。

适合复用场景：

- `GetMaterialApp.builder`。
- 需要把某个局部预览区域固定为手机宽度时。

不适合复用场景：

- 普通页面内部布局。
- 游戏棋盘、卡牌市场等需要自适应宽度的区域。

示例：

```dart
builder: (context, child) {
  return MobileViewport(
    child: child ?? const SizedBox.shrink(),
  );
}
```

## 当前核心 App 方法和配置

### 启动与尺寸

- `main()`：设置竖屏和系统 UI，再启动 `BoardGameAiApp`。
- `ScreenUtilInit(designSize: Size(393, 852))`：统一移动端尺寸适配。
- `.w / .h / .sp`：页面尺寸、间距、图标和字体适配优先使用 `flutter_screenutil`。
- `MobileViewport.maxPhoneWidth = 480`：限制大屏下内容宽度。

使用规则：

- 页面内间距优先使用 `20.w`、`16.h`、`24.sp` 这类写法。
- 固定格式 UI，例如卡片比例、棋盘、按钮高度，必须给稳定尺寸或约束，避免内容变化导致布局跳动。

### 路由

- 路由名称统一写在 `AppRoutes`。
- 页面跳转使用 `Get.toNamed(AppRoutes.xxx)`。
- 不要在页面中散落 `'/some-route'` 字符串。

### 主题

- 全局颜色和组件默认样式写在 `AppTheme.light`。
- 全局颜色常量写在 `AppColors`。
- 页面里优先读取：

```dart
final colorScheme = Theme.of(context).colorScheme;
final textTheme = Theme.of(context).textTheme;
```

颜色使用规则：

- 主题语义色优先用 `colorScheme`。
- 需要固定业务或视觉语义的颜色，优先加到 `AppColors`。
- 不重复写已经存在的十六进制颜色值。

### 网络

- 网络请求统一走 `ApiClient`。
- 业务接口编排优先放在对应页面域的 `controller/` 子目录。
- 页面只负责展示，接口调用和状态推进交给 controller。
- controller 不负责长期承载复杂规则；当同一流程被多个页面复用，或出现 Bot/AI/本地规则推进时，抽到 `services/`。

### 资源

- Flutter 资源统一登记在 `frontend/pubspec.yaml` 的 `flutter.assets`。
- 当前已登记 `images/splendor/bg.webp`，用于首页璀璨宝石入口封面图。
- 页面中使用 `Image.asset('images/splendor/bg.webp')` 读取。

## 后续新增文件的登记模板

新增文件后，在本文档补一节，按下面字段写清楚：

```text
### `frontend/lib/xxx/yyy.dart`

职责：

- ...

核心类：

- ...

核心方法：

- ...

用法：

- 示例：`Get.toNamed(AppRoutes.xxx)`

复用说明：

- ...

备注情况：

- 文件、核心类、核心方法是否已经写明用途。
```

新增可复用 widget 时，在“当前可复用 Widget”补：

```text
### `WidgetName`

文件：

用途：

参数：

适合复用场景：

不适合复用场景：

示例：

备注情况：
```

## 近期前端落点

下一步建议按以下顺序增加文件，并同步更新本文档：

1. 接入真实大模型 Provider 前，先保持 `SplendorAiAdvicePanel` 的结构化字段稳定。
2. 后续可在 AI 建议面板增加流式输出和桌面轻量高亮，但不要让面板直接执行行动。
3. 继续优化卡面排版，必要时再把卡牌/贵族 tile 抽成可复用组件。

每一步都先保证职责清晰，不把规则逻辑写进页面。
