# Splendor AI 前置文档

版本：2026-06-16  
目标：为 boardGameAi 的第一个游戏「璀璨宝石 / Splendor」建立规则、状态建模、行动评估和高阶玩家思路的基础文档，方便后续接入 AI 建议系统。

## 1. 游戏定位

Splendor 是一个 2-4 人的轻中度策略游戏，核心机制是：

- 资源管理：拿取宝石 token。
- 引擎构筑：购买发展卡，获得永久折扣。
- 公开市场竞速：所有玩家争夺桌面可见卡和贵族。
- 节奏控制：谁先达到 15 分会触发终局。
- 低随机高战术：随机主要来自牌堆翻牌，绝大部分状态公开。

对 AI 来说，Splendor 不是“单纯当前收益最大”的游戏。它更像一个短时程优化问题：每一步都要比较 tempo、未来折扣、卡牌可抢性、贵族路线、对手威胁和终局回合数。

## 2. 官方规则摘要

### 2.1 组件

标准基础版包含：

- 5 种普通宝石 token：白、蓝、绿、红、黑，每种 7 个。
- 黄金 token：5 个，可作为任意颜色支付。
- 90 张发展卡：一级 40 张、二级 30 张、三级 20 张。
- 10 张贵族 tile。

不同人数会减少普通宝石和贵族数量：

- 2 人：每种普通宝石 4 个，贵族 3 张。
- 3 人：每种普通宝石 5 个，贵族 4 张。
- 4 人：每种普通宝石 7 个，贵族 5 张。

### 2.2 回合行动

每回合只能执行一个行动：

- 拿 3 个不同颜色的普通宝石。
- 拿 2 个同色普通宝石，但该颜色在拿之前必须至少剩 4 个。
- 预定 1 张发展卡，并拿 1 个黄金。如果没有黄金，也可以预定，但拿不到黄金。每人最多保留 3 张预定卡。
- 购买 1 张公开发展卡，或购买自己已预定的发展卡。

### 2.3 折扣和支付

每张已购买的发展卡提供一个对应颜色的永久 bonus。购买新卡时，每个 bonus 抵扣对应颜色 1 个成本。黄金 token 可以代替任意颜色 token。

### 2.4 token 上限

玩家回合结束时最多只能持有 10 个 token，包含黄金。超过 10 个必须弃回公共池。

### 2.5 贵族

玩家回合结束时，如果已购买发展卡的 bonus 满足贵族要求，则自动获得贵族。贵族不是行动，每张通常 3 分。每回合最多获得 1 张贵族；如果同时满足多张，由玩家选择。

### 2.6 终局

当任一玩家在自己回合结束时达到或超过 15 分，触发终局。当前轮继续进行，直到所有玩家行动次数相同。最终分数最高者获胜；平分时，购买发展卡更少者胜。

## 3. AI 状态建模

### 3.1 全局状态

建议至少记录：

```text
GameState
  playerCount
  currentPlayerIndex
  startPlayerIndex
  tokenPool[5 colors + gold]
  visibleCards[level1][4]
  visibleCards[level2][4]
  visibleCards[level3][4]
  deckRemainingCount[level1..3]
  nobles[]
  players[]
  turnNumber
  finalRoundTriggered
```

### 3.2 玩家状态

```text
PlayerState
  score
  tokens[5 colors + gold]
  bonuses[5 colors]
  purchasedCards[]
  reservedCards[]
  nobles[]
  turnOrderIndex
```

### 3.3 卡牌状态

```text
Card
  id
  level
  bonusColor
  prestige
  cost[5 colors]
```

### 3.4 贵族状态

```text
Noble
  id
  prestige = 3
  requirement[5 colors]
```

## 4. 合法行动枚举

AI 每回合应先生成合法行动，再评分。

### 4.1 拿 token

合法行动包括：

- 所有可拿的 3 色组合。
- 基础规则实现建议默认要求拿 3 个不同色；如果后续支持平台变体或扩展规则，再单独配置是否允许在公共池颜色不足时少拿。
- 所有可拿 2 个同色的颜色，前提是该色公共池数量 >= 4。
- 拿 token 后如果玩家 token 总数 > 10，需要枚举弃 token 组合，或者在搜索中把弃 token 当作行动的一部分。

### 4.2 预定卡

合法行动包括：

- 预定桌面任意公开卡。
- 盲抽预定任意等级牌堆顶牌，如果牌堆还有牌。
- 如果玩家已有 3 张预定卡，则不能预定。
- 如果公共池有黄金，拿 1 黄金；否则只预定不拿黄金。

### 4.3 买卡

合法行动包括：

- 买任意自己支付得起的公开卡。
- 买任意自己支付得起的预定卡。
- 支付计算应优先使用普通 token，不足部分用黄金补齐。
- 购买公开卡后立刻补牌。

## 5. 高阶玩家思路

### 5.1 核心原则：不要只看分，看回合效率

Splendor 的关键不是“买最多卡”，而是“用最少回合到 15 分”。AI 应优先估算：

```text
目标卡预计还需要几回合？
这一步是否缩短到 15 分的路径？
这张卡是否同时提供分数、折扣、贵族进度、对手阻断？
```

一个简单指标：

```text
cardEfficiency = prestige / expectedTurnsToBuy
```

但成熟 AI 不应只用这个指标，因为 0 分低级卡可能通过折扣让后续高分卡少花多个回合。

### 5.2 开局：观察贵族和二级牌，不要盲目扫一级牌

开局不要只看一级便宜卡。更强的思路是：

- 先看贵族需要哪些颜色。
- 再看桌面二级牌里哪些是 2-3 分且成本集中。
- 决定前 3-5 回合的主色路线。

常见好路线：

- 围绕 1-2 张二级高性价比牌建立颜色。
- 顺路靠近 1 个贵族，而不是为了贵族买一堆低效 0 分卡。
- 如果桌面有明显强卡，优先拿能买它的 token，必要时预定。

不推荐：

- 为了“颜色均衡”什么都买一点。
- 前期买太多 0 分卡但没有通往二级/三级分牌。
- 只追贵族，导致分数启动太慢。

### 5.3 中期：从引擎切换到得分

Splendor 很容易出现“引擎构筑过度”。AI 要识别中期切换点：

- 当玩家有 4-6 张发展卡后，应开始重视直接分数。
- 当玩家已经接近某个贵族时，继续补对应颜色是合理的。
- 如果已有折扣能低成本买二级/三级分牌，就不要继续买无关 0 分牌。

中期评估应加入：

```text
scorePressure = 当前分数 + 未来2-3回合可获得分数
```

如果自己落后，但拥有更强折扣和预定高分牌，不一定是真落后。AI 应评估“潜在爆发分”。

### 5.4 后期：计算终局，而不是继续铺垫

后期目标是尽快到 15 分或阻止对手到 15 分。此时：

- 3 分以上的卡价值明显上升。
- 贵族如果只差 1 张颜色卡，价值很高。
- 预定对手马上能买的高分卡是强防守。
- 不再值得买与终局无关的 0 分卡，除非它能让下一张关键分牌免费或触发贵族。

后期 AI 必须计算：

```text
myTurnsTo15
opponentTurnsTo15
canITriggerFinalRound
doesOpponentGetLastMove
```

触发 15 分不一定必胜，因为同一轮后手可能反超。

### 5.5 预定不是保守动作，是节奏工具

预定有三种价值：

- 进攻：锁定自己未来要买的高价值卡。
- 防守：拿走对手即将购买的关键卡。
- 资源：获得黄金，补齐难拿颜色。

高水平玩家不会乱预定。好的预定通常满足至少一条：

- 这张卡 1-3 回合内可以买到。
- 这张卡是对手路线的关键分牌或关键颜色。
- 这张卡能触发贵族或直接进入终局。
- 当前 token 池让你很难自然拿到目标颜色，需要黄金。

差的预定：

- 只是因为“这张牌看起来不错”，但买不到。
- 预定太多导致手牌满，后续无法抢关键卡。
- 预定低价值牌，浪费黄金机会。

### 5.6 贵族是加速器，不是唯一目标

贵族 3 分很诱人，但它要求特定颜色数量。AI 应把贵族当作“顺路收益”：

- 如果贵族需求和当前高分牌路线重合，积极追。
- 如果为了贵族要买很多低效 0 分卡，应降低优先级。
- 如果多个玩家都接近同一贵族，要估算谁先完成。

贵族评分可用：

```text
nobleProgress = sum(min(myBonus[color], req[color])) / sum(req[color])
nobleMissing = sum(max(0, req[color] - myBonus[color]))
```

但不能只看 missing 数量，还要看缺的颜色是否容易买、是否和分牌路线一致。

### 5.7 抢牌和阻断

Splendor 的交互主要来自公开市场。AI 要识别对手的目标：

- 对手 token 已经能买哪张卡？
- 对手缺 1-2 个 token 的高分卡是哪张？
- 对手接近哪个贵族？
- 对手预定卡是否会形成爆发？

阻断动作包括：

- 自己买走对手目标卡。
- 预定对手目标卡。
- 拿走对手需要的关键 token，特别是公共池稀缺颜色。

阻断不应滥用。只有当阻断收益大于自己推进收益时才做。

### 5.8 token 池管理

token 不是无限资源。强 AI 要关注公共池稀缺性：

- 某颜色只剩 0-1 个时，该色路线会变慢。
- 同色拿 2 要求公共池至少 4 个，因此当池里刚好 4 个时，拿 2 可以制造节奏优势。
- 黄金越少，预定的资源价值越低，但防守价值仍可能存在。
- 持有 8-10 个 token 时，继续拿 token 的边际价值下降，因为可能被迫弃牌。

### 5.9 颜色价值不是固定的

某个颜色是否重要，取决于：

- 当前公开牌成本分布。
- 贵族需求。
- 自己已有 bonus。
- 对手路线。
- token 池剩余。

AI 不应硬编码“某颜色更强”。应动态计算颜色需求。

可计算：

```text
colorDemand[color] =
  visibleCardCostsWeighted[color]
  + nobleRequirementWeighted[color]
  + reservedCardNeed[color]
  - myBonus[color]
```

### 5.10 终局 tie-breaker

平分时，购买发展卡更少者胜。因此后期如果能用更少卡达到同分，应偏向高分卡和贵族，而不是大量低分卡。

AI 评估终局时要记录：

```text
score
purchasedCardCount
turnOrder
reservedThreat
```

## 6. 建议的 AI 评估函数

一个早期可用的启发式评分：

```text
stateValue =
  score * 100
  + potentialScoreNext2Turns * 45
  + bonusValue * 12
  + nobleProgressValue * 25
  + reservedCardValue * 8
  + tokenFlexibilityValue * 6
  - wastedTokenPenalty * 10
  - opponentImmediateThreat * 60
```

### 6.1 分数

当前分数权重最高，尤其是中后期。

```text
scoreValue = player.score
```

### 6.2 未来两回合潜在分

估算玩家在 1-2 回合内可购买的最高价值牌和可触发贵族。

```text
potentialScoreNext2Turns =
  maxPrestigeBuyableSoon
  + nobleTriggerSoonScore
```

### 6.3 bonus 价值

bonus 的价值应随阶段下降：

- 开局 bonus 价值高。
- 中期 bonus 价值中。
- 后期只有能连接分牌/贵族的 bonus 才高。

```text
bonusValue[color] = demandAdjustedColorValue[color] * myBonus[color]
```

### 6.4 token 灵活性

黄金、稀缺颜色、多色组合更灵活。

```text
tokenFlexibility =
  gold * highWeight
  + sum(tokens[color] * colorDemand[color])
```

### 6.5 对手威胁

对每个对手估算：

- 是否当前能买 3 分以上牌。
- 是否 1 回合内能触发贵族。
- 是否 1-2 回合内能到 15 分。
- 是否能在你触发终局后反超。

```text
opponentImmediateThreat =
  max(opponentCanScoreThisTurn, opponentTurnsTo15Threat)
```

## 7. AI 建议输出格式

为了让 App 给出高质量建议，建议 AI 输出不要只说“拿红蓝绿”。应输出：

```json
{
  "recommendedAction": {
    "type": "take_tokens",
    "tokens": ["red", "blue", "green"]
  },
  "confidence": 0.74,
  "reasoning": [
    "这组 token 可以在下回合买到二级蓝色 2 分牌",
    "绿色同时推进左侧贵族需求",
    "红色公共池只剩 2 个，先拿可以阻止下家凑齐三级牌成本"
  ],
  "alternatives": [
    {
      "action": "reserve_card",
      "targetCardId": "L2-B-17",
      "reason": "如果担心下家先买，可以预定，但会延后自身得分节奏"
    }
  ],
  "threats": [
    "下家已有 4 蓝 2 白，下回合可能购买 3 分黑牌"
  ]
}
```

## 8. 分阶段策略模板

### 开局模板

```text
1. 识别贵族重叠颜色。
2. 找 1-2 张二级高性价比分牌作为路线核心。
3. 买一级卡时优先选择能服务二级牌/贵族的颜色。
4. 避免无目标地买 0 分牌。
```

### 中期模板

```text
1. 评估自己是否已具备得分能力。
2. 优先买 2-3 分牌，顺路补贵族。
3. 对手即将拿高分牌时考虑预定阻断。
4. 控制 token 不超过 10，避免拿一堆无法转化的资源。
```

### 后期模板

```text
1. 计算自己到 15 分需要几回合。
2. 计算对手到 15 分需要几回合。
3. 如果能触发终局，确认同轮后手是否能反超。
4. 优先直接得分和贵族，不再铺无关引擎。
```

## 9. App 实现建议

### 9.1 第一阶段

先实现规则引擎：

- 状态表示。
- 合法行动生成。
- 行动执行和回滚。
- 胜负判定。
- 简单启发式 AI。

### 9.2 第二阶段

实现建议系统：

- 对当前所有合法行动评分。
- 输出推荐行动、理由、备选行动、对手威胁。
- 允许用户切换“保守 / 平衡 / 激进”风格。

### 9.3 第三阶段

接入大模型：

- 规则和策略文档作为静态上下文。
- 当前局面用结构化 JSON 输入。
- 让模型只负责解释、权衡和生成自然语言建议。
- 真正的合法性校验和行动枚举仍由本地规则引擎完成。

不要让大模型直接判断行动是否合法。规则引擎应该先给出合法行动列表，大模型只能在合法行动中选择和解释。

## 10. 推荐给模型的系统约束

后续可以把下面这段作为 AI 建议器的系统提示词核心：

```text
你是 Splendor 高阶策略助手。你必须只从输入提供的合法行动列表中推荐行动。你的目标不是解释规则，而是在当前局面中最大化玩家获胜概率。评估时必须考虑：当前分数、到 15 分的回合数、发展卡折扣、贵族进度、token 上限、黄金价值、公开市场卡牌、对手即将购买的卡、对手贵族威胁、终局同轮反超风险。不要推荐非法行动。如果信息不足，说明缺失的信息，并给出基于已知状态的保守建议。
```

## 11. 资料来源

- Space Cowboys 官方 Splendor 页面，包含游戏定位、组件、基础玩法和规则下载入口：  
  https://www.spacecowboys-games.com/fr/game/splendor/
- Space Cowboys / Asmodee 官方法语规则 PDF，规则细节包括行动、预定、购买、bonus、贵族、终局和人数配置：  
  https://cdn.svc.asmodee.net/production-spacecowboys/uploads/2025/12/FR_SPLENDOR_Rules.pdf
- UltraBoardGames 的英文规则整理，用于交叉核对基础版英文规则表述：  
  https://www.ultraboardgames.com/splendor/game-rules.php
- Wikipedia 的 Splendor 条目，用于核对游戏类型、组件、回合动作和公开信息结构：  
  https://en.wikipedia.org/wiki/Splendor_%28game%29
- Ivan Bravi 等，Rinascimento: Optimising Statistical Forward Planning Agents for Playing Splendor，用于参考 Splendor AI 中的前向规划、参数调优和多智能体挑战：  
  https://arxiv.org/abs/1904.01883
- Ivan Bravi, Simon Lucas，Rinascimento: using event-value functions for playing Splendor，用于参考事件价值函数和稀疏奖励问题：  
  https://arxiv.org/abs/2006.05894
- Ivan Bravi, Simon Lucas，Rinascimento: searching the behaviour space of Splendor，用于参考行为空间、AI play-testing 和策略行为度量：  
  https://arxiv.org/abs/2106.08371
