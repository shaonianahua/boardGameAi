# boardGameAi

单仓库结构：

- `frontend/`：Flutter 客户端
- `backend/`：本地后端服务
- `data/`：本地数据库、种子数据、快照
- `docs/`：产品、架构、游戏策略文档

常用命令：

```bash
cd frontend
fvm flutter run
```

后端和数据库骨架后续在 `backend/` 下继续补。

后端本地运行：

```bash
cd backend
npm install
npm run prisma:migrate -- --name init
npm run dev
```

