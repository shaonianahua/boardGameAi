# AI 接入设计

版本：2026-06-18

## 目标

本项目 V2 开始接入 DeepSeek 等云端大模型，让 AI 能在璀璨宝石对局中提供策略建议；本地 Bot 仍使用启发式策略自动陪玩。V3 再考虑让大模型接管 Bot 玩家或承担复盘增强。

AI 功能的边界：

- AI 不负责判断规则是否合法。
- AI 不直接修改 `GameState`。
- AI 只能从后端规则引擎生成的 `legalActions` 中选择一个行动。
- 后端必须再次校验 AI 返回的 `actionId` 是否存在于合法行动列表。
- 如果 AI 返回非法行动或格式错误，后端回退到本地启发式 AI。

## Prompt 文件位置

运行时 prompt 放在后端：

```text
backend/src/features/splendor/ai/prompts/splendor-advisor.md
```

这个 prompt 是给 DeepSeek 等模型运行时使用的，不是 Codex Skill。

## 为什么放后端

DeepSeek API Key 不能放在 Flutter App 里。

推荐调用链：

```text
Flutter
  -> backend /api/splendor/sessions/:sessionId/ai/decide
    -> 读取 GameState
    -> 生成 legalActions
    -> 调用 DeepSeek
    -> 校验模型输出
    -> 返回建议或执行 Bot 行动
```

## V2 功能边界

V2 同时做两条 AI 相关能力：

- 本地 Bot：不调用大模型，只根据合法行动和评分函数自动选择行动，用于人机对局和模型失败兜底。
- AI 建议：真人玩家点击按钮后调用大模型，返回推荐行动、理由、备选方案、对手威胁和风险提示。V2 第一版先建议不代操作，后续再加“采纳建议”。

V2 的 AI 建议重点不是普通聊天框，而是“AI 读懂当前桌面并给出可执行策略”：

- 前端使用底部策略面板或侧滑面板承载建议。
- 模型返回可以先非流式，跑通后升级流式展示。
- 流式展示建议按段落输出：结论、理由、对手威胁、备选方案、风险。
- 前端后续可根据返回的行动或目标，对相关卡牌、宝石做轻量高亮。

## V2 当前前两步实现

当前先实现两步闭环，先保证 AI 建议有稳定的数据边界，再替换真实大模型：

1. 结构化建议链路：后端新增 `POST /api/splendor/sessions/:sessionId/ai/decide`，读取当前 `GameState` 和 `legalActions`，复用本地 Bot 评分逻辑生成 `decision` 与 `selectedAction`。这一版不调用大模型，也不执行行动。
2. 前端建议入口：真人当前回合展示“AI 建议”按钮，调用 `SplendorApi.requestAiAdvice`，由 `SplendorAiAdvicePanel` 展示结论、推荐行动、理由、备选、威胁和风险。面板只读展示，不自动采纳行动。

后续接 DeepSeek 时，应替换后端建议生成器，不改变 Flutter 侧 `SplendorAiAdviceResponse` 的基本展示字段。

## DeepSeek 计划配置

后续 `.env` 建议增加：

```env
AI_PROVIDER=deepseek
DEEPSEEK_API_KEY=your_key
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-v4-flash
DEEPSEEK_TIMEOUT_MS=180000
SPLENDOR_AI_STYLE=balanced
```

当前后端已读取 `backend/.env`，真实 Key 只放本地 `.env`，不要提交到 git。

## DeepSeek 调用策略

后端不直接把整篇策略文档每次都发给模型，而是使用固定 prompt + 当前局面 JSON。

调试要求：

- 后端日志只打印 provider、耗时、token usage、fallback 原因和安全诊断摘要。
- 不打印 API Key，也不打印完整 prompt。
- DeepSeek 返回空内容时，要记录 `finish_reason`、message 字段名、usage 和裁剪后的响应摘要，避免前端只看到“模型暂不可用”却无法判断原因。

输入包含：

- `gameState`：当前完整局面。
- `catalog`：卡牌和贵族定义，可按需要裁剪为当前可见卡、预定卡、贵族。
- `legalActions`：后端生成的合法行动列表，每个行动带 `actionId`。
- `actionHistory`：近期行动历史，用于判断其他玩家可能目标；输入时应控制长度。
- `currentPlayerIndex`：当前玩家。
- `style`：AI 风格，例如 `balanced`、`aggressive`、`engine`、`noble`、`blocking`。

输出必须是 JSON：

```json
{
  "actionId": "string-or-null",
  "confidence": 0.78,
  "summary": "建议拿白蓝绿，为下回合购买二级牌做准备。",
  "reasoning": [],
  "alternatives": [],
  "threats": [],
  "risks": []
}
```

字段说明：

- `actionId`：推荐行动 ID，必须能匹配 `legalActions`。
- `confidence`：模型对推荐的信心，供前端显示强弱。
- `summary`：顶部结论，适合在面板首屏直接展示。
- `reasoning`：推荐理由，说明短期收益和后续路线。
- `alternatives`：备选行动，避免用户只看到单一路线。
- `threats`：其他玩家可能购买的卡、贵族进度或需要阻断的目标。
- `risks`：当前推荐的风险，例如关键卡可能被抢、宝石上限压力。

## 后端需要新增的模块

建议后续新增：

```text
backend/src/features/splendor/ai/
├── prompts/
│   └── splendor-advisor.md
├── ai-provider.ts
├── deepseek-provider.ts
├── heuristic-advisor.ts
├── advisor-service.ts
└── schemas.ts
```

文件职责：

- `ai-provider.ts`：定义统一 AI Provider 接口。
- `deepseek-provider.ts`：封装 DeepSeek OpenAI 兼容接口调用，读取 prompt 并要求 JSON 输出。
- `heuristic-advisor.ts`：后续可拆出本地启发式 fallback；当前 fallback 暂保留在 `advisor-service.ts`。
- `advisor-service.ts`：读取状态、生成候选、调用模型、校验输出；模型失败时回退启发式。
- `schemas.ts`：定义 AI 输出结构校验，确保 `actionId` 必须命中合法行动。

## 后端需要新增的接口

建议新增：

```text
POST /api/splendor/sessions/:sessionId/ai/decide
```

请求：

```json
{
  "playerIndex": 1,
  "style": "balanced",
  "mode": "suggest"
}
```

`mode`：

- `suggest`：只返回建议，不执行行动。
- `execute`：AI 选择行动后，后端执行该行动并写入行动历史；V2 可以先不开放给真人建议，只用于后续 Bot 接管。

返回：

```json
{
  "decision": {
    "actionId": "action-001",
    "confidence": 0.78,
    "summary": "建议拿白蓝绿。",
    "reasoning": [],
    "alternatives": [],
    "threats": [],
    "risks": []
  },
  "selectedAction": {}
}
```

流式版本可以后续增加：

```text
POST /api/splendor/sessions/:sessionId/ai/stream
```

流式接口优先输出展示内容，最终再输出结构化 `decision`。如果 V2 第一版非流式已经满足演示，可以等 UI 稳定后再实现流式。

## 必须先补的能力

接入 DeepSeek 前，后端还需要先实现：

- 合法行动枚举：已具备，AI 建议只从后端合法行动列表中选择。
- `actionId` 生成规则：已用稳定 action key 生成，模型返回必须命中这些 ID。
- DeepSeek Provider：已具备，调用 `POST /chat/completions`，使用 `response_format: json_object`。
- 本地启发式 fallback：已复用 Bot 评分逻辑；模型未配置、余额不足、超时、JSON 非法、actionId 非法时都会回退。
- 前端 AI 建议面板和加载状态：已具备非流式只读版本。
- AI 输出 JSON 校验：已具备第一版，后续可继续加强字段长度、语言风格和安全策略。
- AI 调试日志：已在 DeepSeek 空内容、非 JSON、非法 actionId 等失败路径保留安全摘要，方便真机触发一次后定位问题。
- `AiDecision` 写库：需要后续补，便于复盘、调试和模型效果评估。

否则模型没有稳定边界，容易输出非法操作。

## 面试可讲的设计点

这个 AI 设计的核心不是“把局面扔给大模型”，而是：

- 规则确定性由代码负责。
- 策略不确定性由模型辅助。
- 大模型只能在合法行动里选择。
- 模型输出必须结构化校验。
- 模型失败时系统可回退。
- token 成本可控，因为只传当前状态和候选行动，不传完整长文档。
