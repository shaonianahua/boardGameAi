import type { FastifyInstance } from 'fastify';
import { splendorCards, splendorNobles } from './catalog.js';
import {
  actSplendorBot,
  createSplendorSession,
  getSplendorAdvice,
  getSplendorAdviceStream,
  getSplendorLegalActions,
  getSplendorSession,
  listSplendorActions,
  submitSplendorAction,
} from './service.js';
import type { CreateSplendorSessionInput, SubmitSplendorActionInput } from './types.js';

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'unknown error';
}

function errorCode(error: unknown): string {
  const message = errorMessage(error);
  return message
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toUpperCase() || 'UNKNOWN_ERROR';
}

function errorResponse(error: unknown): { error: { code: string; message: string } } {
  return {
    error: {
      code: errorCode(error),
      message: errorMessage(error),
    },
  };
}

export async function registerSplendorRoutes(app: FastifyInstance): Promise<void> {
  app.get('/api/splendor/catalog', async () => {
    return {
      cards: splendorCards,
      nobles: splendorNobles,
    };
  });

  app.post('/api/splendor/sessions', async (request, reply) => {
    try {
      const result = await createSplendorSession(request.body as CreateSplendorSessionInput);
      return result;
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.get('/api/splendor/sessions/:sessionId', async (request, reply) => {
    try {
      const params = request.params as { sessionId: string };
      return await getSplendorSession(params.sessionId);
    } catch (error) {
      return reply.status(404).send(errorResponse(error));
    }
  });

  app.get('/api/splendor/sessions/:sessionId/legal-actions', async (request, reply) => {
    try {
      const params = request.params as { sessionId: string };
      return await getSplendorLegalActions(params.sessionId);
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.post('/api/splendor/sessions/:sessionId/actions', async (request, reply) => {
    try {
      const params = request.params as { sessionId: string };
      return await submitSplendorAction(
        params.sessionId,
        request.body as SubmitSplendorActionInput,
      );
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.get('/api/splendor/sessions/:sessionId/actions', async (request, reply) => {
    try {
      const params = request.params as { sessionId: string };
      return { actions: await listSplendorActions(params.sessionId) };
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.post('/api/splendor/sessions/:sessionId/bot/act', async (request, reply) => {
    try {
      const params = request.params as { sessionId: string };
      return await actSplendorBot(params.sessionId);
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.post('/api/splendor/sessions/:sessionId/ai/decide', async (request, reply) => {
    try {
      const params = request.params as { sessionId: string };
      return await getSplendorAdvice(params.sessionId);
    } catch (error) {
      return reply.status(400).send(errorResponse(error));
    }
  });

  app.post('/api/splendor/sessions/:sessionId/ai/stream', async (request, reply) => {
    try {
      const params = request.params as { sessionId: string };
      const stream = await getSplendorAdviceStream(params.sessionId);
      reply.raw.writeHead(200, {
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache, no-transform',
        Connection: 'keep-alive',
      });

      for await (const event of stream) {
        reply.raw.write(`event: ${event.type}\n`);
        reply.raw.write(`data: ${JSON.stringify(event)}\n\n`);
      }
      reply.raw.end();
    } catch (error) {
      if (!reply.raw.headersSent) {
        return reply.status(400).send(errorResponse(error));
      }
      reply.raw.write(`event: error\n`);
      reply.raw.write(`data: ${JSON.stringify(errorResponse(error))}\n\n`);
      reply.raw.end();
    }
  });

  app.post('/api/splendor/advice', async (request) => {
    const body = request.body as Record<string, unknown>;

    return {
      recommendedAction: {
        type: 'take_tokens',
        tokens: { white: 1, blue: 1, green: 1 },
      },
      confidence: 0.45,
      reasoning: [
        '先用启发式占位，后面会接规则评分器和模型。',
        '当前接口已打通，可用于 Flutter 联调。',
      ],
      threats: [],
      inputEcho: body,
    };
  });
}
