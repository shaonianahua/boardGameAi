# Flutter App 架构索引

版本：2026-06-17

## 使用要求

每次处理 Flutter App 相关任务前，必须先阅读本文件和仓库根目录的 `AGENTS.md`。

本文件用于记录 `frontend/lib/` 下的 App 架构、文件职责、核心类、核心方法、可复用 widget 和使用方式。后续新增或修改页面、路由、主题、模型、服务、公共组件时，都要同步更新本文件。

## 当前目标

当前 App 阶段先实现璀璨宝石本地同屏对局。前端重点是：

- 页面展示和交互。
- 本地游戏状态结构。
- 规则服务和 Action 执行流程。
- 后续接入后端存档、Bot 和 AI 策略时可复用同一套状态与行动结构。

暂不在首页或 UI 组件里写复杂规则逻辑。页面负责展示和收集用户操作，规则判断和状态变更放到 `services/`。

## 目录总览

```text
frontend/lib/
├── main.dart
├── app/
│   ├── app_colors.dart
│   ├── app.dart
│   ├── routes.dart
│   └── theme.dart
├── models/
│   └── splendor/
├── pages/
│   ├── index/
│   │   └── index_page.dart
│   └── splendor/
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
- `app/`：App 级配置，包括 App 外壳、路由、主题和颜色表。
- `models/`：纯数据模型，按游戏或模块拆分，不依赖页面。
- `pages/`：页面、页面 Controller、页面内部组件，按页面或游戏拆分。
- `services/`：业务服务、规则服务、固定数据、状态推进逻辑。
- `shared/`：确认跨页面或跨游戏复用的网络、widget 和工具。

`models/splendor/`、`pages/splendor/`、`services/splendor/` 是后续璀璨宝石对局实现位置。创建这些文件时要继续补全本索引。

## 文件职责

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

核心成员：

- `static const index = '/'`：首页路径。
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
- `_GameEntryCard.onStart`：点击“开始对局”后的回调入口。当前使用 `Get.snackbar` 提示“对局页将在下一步接入”。

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
- 统一配置 JSON 请求、JSON 响应、连接超时和接收超时。
- 提供 `setBearerToken` 管理 Authorization header。

核心类：

- `ApiClient`

构造参数：

- `dio`：可选，测试或特殊场景可注入自定义 Dio。
- `baseUrl`：可选，默认空字符串。当前不写死后端地址，避免在基础设施层提前绑定环境。
- `connectTimeout`：连接超时，默认 15 秒。
- `receiveTimeout`：接收超时，默认 15 秒。

核心成员：

- `dio`：暴露底层 Dio，只在确实需要添加 interceptor 或处理特殊能力时使用。
- `authorizationHeader`：Authorization header 名称常量。

核心方法：

- `setBearerToken(String? token)`：设置或清除 `Authorization: Bearer xxx`。
- `get<T>(String path, ...)`：发送 GET 请求。
- `post<T>(String path, ...)`：发送 POST 请求。
- `put<T>(String path, ...)`：发送 PUT 请求。
- `delete<T>(String path, ...)`：发送 DELETE 请求。

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
- 业务接口文件后续放在对应模块服务目录，例如 `services/splendor/`。
- 模块服务通过构造函数接收 `ApiClient`，不要在页面里直接创建 Dio。

示例：

```dart
class SplendorRemoteService {
  SplendorRemoteService(this._apiClient);

  final ApiClient _apiClient;
}
```

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
```

## 近期前端落点

下一步建议按以下顺序增加文件，并同步更新本文档：

1. `pages/splendor/create_session_page.dart`：创建璀璨宝石对局，选择玩家人数和玩家名称。
2. `pages/splendor/splendor_table_page.dart`：璀璨宝石对局桌面页面。
3. `models/splendor/`：宝石、卡牌、贵族、玩家、GameState、Action、操作记录。
4. `services/splendor/`：catalog、规则判断、对局初始化、行动执行。

每一步都先保证职责清晰，不把规则逻辑写进页面。
