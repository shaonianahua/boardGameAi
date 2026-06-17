import Fastify from 'fastify';
import { prisma } from './db/prisma.js';
import { registerSplendorRoutes } from './features/splendor/routes.js';

const app = Fastify({ logger: true });
const port = Number(process.env.PORT ?? 3000);

app.get('/health', async () => {
  return {
    ok: true,
    service: 'boardgameai-backend',
    time: new Date().toISOString(),
  };
});

await registerSplendorRoutes(app);

async function main() {
  await app.listen({ port, host: '0.0.0.0' });
}

main().catch(async (error) => {
  app.log.error(error);
  await prisma.$disconnect();
  process.exit(1);
});
