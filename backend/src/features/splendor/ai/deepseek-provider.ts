import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { SplendorAdviceDecision } from '../advisor-service.js';
import type { SplendorAdvisorInput, SplendorAiProvider } from './ai-provider.js';
import { parseSplendorAdviceDecision } from './schemas.js';

interface DeepSeekChatResponse {
  id?: string;
  model?: string;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    total_tokens?: number;
  };
  choices?: Array<{
    finish_reason?: string | null;
    index?: number;
    message?: {
      role?: string;
      content?: string | null;
      reasoning_content?: string | null;
      refusal?: string | null;
      tool_calls?: unknown;
      [key: string]: unknown;
    };
  }>;
  error?: unknown;
  [key: string]: unknown;
}

export interface DeepSeekProviderOptions {
  apiKey: string;
  baseUrl: string;
  model: string;
  timeoutMs: number;
}

export interface DeepSeekDecisionResult {
  decision: SplendorAdviceDecision;
  usage: {
    promptTokens: number | null;
    completionTokens: number | null;
    totalTokens: number | null;
  };
}

const promptPath = join(
  dirname(fileURLToPath(import.meta.url)),
  'prompts',
  'splendor-advisor.md',
);

const sourcePromptPath = join(
  process.cwd(),
  'src',
  'features',
  'splendor',
  'ai',
  'prompts',
  'splendor-advisor.md',
);

/// DeepSeek OpenAI 兼容接口实现。
///
/// 只负责调用模型和校验 JSON 输出；规则合法性仍由 advisor-service 的合法行动集合保证。
export class DeepSeekSplendorProvider implements SplendorAiProvider {
  constructor(private readonly options: DeepSeekProviderOptions) {}

  async decide(input: SplendorAdvisorInput): Promise<SplendorAdviceDecision> {
    return (await this.decideWithMetadata(input)).decision;
  }

  async decideWithMetadata(input: SplendorAdvisorInput): Promise<DeepSeekDecisionResult> {
    const prompt = await readPrompt();
    const response = await this.requestChatCompletion(prompt, input);
    const content = extractMessageContent(response);
    if (!content.trim()) {
      throw new Error(createEmptyContentDiagnostics(response));
    }

    const parsed = parseJsonObject(content);
    return {
      decision: parseSplendorAdviceDecision(
        parsed,
        new Set(input.legalActions.map((action) => action.actionId)),
      ),
      usage: {
        promptTokens: response.usage?.prompt_tokens ?? null,
        completionTokens: response.usage?.completion_tokens ?? null,
        totalTokens: response.usage?.total_tokens ?? null,
      },
    };
  }

  private async requestChatCompletion(
    systemPrompt: string,
    input: SplendorAdvisorInput,
  ): Promise<DeepSeekChatResponse> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.options.timeoutMs);

    try {
      const response = await fetch(`${this.options.baseUrl}/chat/completions`, {
        method: 'POST',
        signal: controller.signal,
        headers: {
          Authorization: `Bearer ${this.options.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: this.options.model,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: JSON.stringify(input) },
          ],
          response_format: { type: 'json_object' },
          thinking: { type: 'disabled' },
          temperature: 0.2,
          max_tokens: 900,
        }),
      });

      const text = await response.text();
      if (!response.ok) {
        throw new Error(`DeepSeek request failed: ${response.status} ${text.slice(0, 500)}`);
      }

      try {
        return JSON.parse(text) as DeepSeekChatResponse;
      } catch {
        throw new Error(`DeepSeek returned non-JSON response: ${text.slice(0, 500)}`);
      }
    } finally {
      clearTimeout(timeout);
    }
  }
}

async function readPrompt(): Promise<string> {
  try {
    return await readFile(promptPath, 'utf8');
  } catch {
    return readFile(sourcePromptPath, 'utf8');
  }
}

function parseJsonObject(content: string): unknown {
  const trimmed = content.trim();
  try {
    return JSON.parse(trimmed) as unknown;
  } catch {
    const match = trimmed.match(/\{[\s\S]*\}/);
    if (!match) {
      throw new Error('DeepSeek content is not JSON');
    }
    return JSON.parse(match[0]) as unknown;
  }
}

function extractMessageContent(response: DeepSeekChatResponse): string {
  const content = response.choices?.[0]?.message?.content;
  if (typeof content === 'string') {
    return content;
  }

  return '';
}

function createEmptyContentDiagnostics(response: DeepSeekChatResponse): string {
  const firstChoice = response.choices?.[0];
  const message = firstChoice?.message;
  const messageKeys = message == null ? [] : Object.keys(message);
  const reasoningContent = typeof message?.reasoning_content === 'string'
    ? message.reasoning_content.trim().slice(0, 160)
    : '';
  const refusal = typeof message?.refusal === 'string'
    ? message.refusal.trim().slice(0, 160)
    : '';
  const bodySnippet = JSON.stringify({
    id: response.id,
    model: response.model,
    choicesLength: response.choices?.length ?? 0,
    finishReason: firstChoice?.finish_reason ?? null,
    messageKeys,
    reasoningContent,
    refusal,
    usage: response.usage,
    error: response.error,
  }).slice(0, 800);

  return `DeepSeek returned empty content: ${bodySnippet}`;
}
