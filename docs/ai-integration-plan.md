# AI 接入设计

版本：2026-06-17

## 目标

本项目后续会接入 DeepSeek API，让 AI 能在璀璨宝石对局中提供策略建议或接管 Bot 玩家。

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

## DeepSeek 计划配置

后续 `.env` 建议增加：

```env
AI_PROVIDER=deepseek
DEEPSEEK_API_KEY=your_key
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-v4-flash
```

## DeepSeek 调用策略

后端不直接把整篇策略文档每次都发给模型，而是使用固定 prompt + 当前局面 JSON。

输入包含：

- `gameState`：当前完整局面。
- `catalog`：卡牌和贵族定义，可按需要裁剪为当前可见卡、预定卡、贵族。
- `legalActions`：后端生成的合法行动列表，每个行动带 `actionId`。
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
- `deepseek-provider.ts`：封装 DeepSeek API 调用。
- `heuristic-advisor.ts`：本地启发式 fallback，不消耗 token。
- `advisor-service.ts`：读取状态、生成候选、调用模型、校验输出、写入 `AiDecision`。
- `schemas.ts`：定义 AI 输入输出结构和校验。

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
- `execute`：AI 选择行动后，后端执行该行动并写入行动历史。

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
  "selectedAction": {},
  "state": {}
}
```

## 必须先补的能力

接入 DeepSeek 前，后端还需要先实现：

- 合法行动枚举。
- `actionId` 生成规则。
- AI 输出 JSON 校验。
- 本地启发式 fallback。
- `AiDecision` 写库。

否则模型没有稳定边界，容易输出非法操作。

## 面试可讲的设计点

这个 AI 设计的核心不是“把局面扔给大模型”，而是：

- 规则确定性由代码负责。
- 策略不确定性由模型辅助。
- 大模型只能在合法行动里选择。
- 模型输出必须结构化校验。
- 模型失败时系统可回退。
- token 成本可控，因为只传当前状态和候选行动，不传完整长文档。

