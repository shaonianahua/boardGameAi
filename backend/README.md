# Backend

本目录是本地后端服务，当前技术栈：

- Node.js
- Fastify
- TypeScript
- Prisma
- SQLite

目录说明：

- `src/`：HTTP 接口和业务代码
- `prisma/`：数据库 schema
- `.env.example`：本地环境变量示例

本地数据库：

- SQLite 文件路径：`../data/sqlite/boardgameai.db`
- 真实数据库文件不提交到 Git
- Prisma migration 提交到 Git

开发命令：

```bash
cd backend
npm install
npm run prisma:migrate -- --name init
npm run dev
```

本地接口：

```bash
curl http://127.0.0.1:3000/health

curl http://127.0.0.1:3000/api/splendor/catalog

curl -X POST http://127.0.0.1:3000/api/splendor/sessions \
  -H 'Content-Type: application/json' \
  -d '{"playerCount":2,"players":[{"name":"A"},{"name":"B"}]}'

curl -X POST http://127.0.0.1:3000/api/splendor/advice \
  -H 'Content-Type: application/json' \
  -d '{"state":{"currentPlayerIndex":0},"legalActions":[]}'
```

Flutter 本地访问：

- iOS 模拟器：`http://127.0.0.1:3000`
- Android 模拟器：`http://10.0.2.2:3000`
- 真机：使用电脑局域网 IP，例如 `http://192.168.x.x:3000`
