import type { SplendorAdviceDecision } from '../advisor-service.js';

/// 把模型输出校验为前端策略面板需要的稳定结构。
///
/// 只接受 actionId 能命中后端合法行动的结果；文本字段会被裁剪成字符串数组。
export function parseSplendorAdviceDecision(
  rawValue: unknown,
  legalActionIds: Set<string>,
): SplendorAdviceDecision {
  if (!isRecord(rawValue)) {
    throw new Error('AI response is not a JSON object');
  }

  const actionId = parseActionId(rawValue.actionId, legalActionIds);
  const confidence = clampNumber(rawValue.confidence, 0, 1);
  const summary = parseText(rawValue.summary, 'AI 已给出建议。');

  return {
    actionId,
    confidence,
    summary,
    reasoning: parseTextList(rawValue.reasoning, 4),
    alternatives: parseAlternativeList(rawValue.alternatives, 3),
    threats: parseTextList(rawValue.threats, 4),
    risks: parseTextList(rawValue.risks, 4),
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function parseActionId(value: unknown, legalActionIds: Set<string>): string | null {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  if (typeof value !== 'string') {
    throw new Error('AI actionId is not a string');
  }
  if (!legalActionIds.has(value)) {
    throw new Error(`AI actionId is not legal: ${value}`);
  }
  return value;
}

function clampNumber(value: unknown, min: number, max: number): number {
  const numericValue = typeof value === 'number' && Number.isFinite(value) ? value : min;
  return Math.min(max, Math.max(min, numericValue));
}

function parseText(value: unknown, fallback: string): string {
  if (typeof value !== 'string') {
    return fallback;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? fallback : trimmed.slice(0, 240);
}

function parseTextList(value: unknown, limit: number): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value
    .filter((item): item is string => typeof item === 'string')
    .map((item) => item.trim())
    .filter((item) => item.length > 0)
    .map((item) => item.slice(0, 260))
    .slice(0, limit);
}

function parseAlternativeList(value: unknown, limit: number): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => {
      if (typeof item === 'string') {
        return item;
      }
      if (isRecord(item)) {
        const actionId = typeof item.actionId === 'string' ? item.actionId : '';
        const reason = typeof item.reason === 'string' ? item.reason : '';
        return [actionId, reason].filter(Boolean).join('：');
      }
      return '';
    })
    .map((item) => item.trim())
    .filter((item) => item.length > 0)
    .map((item) => item.slice(0, 260))
    .slice(0, limit);
}
