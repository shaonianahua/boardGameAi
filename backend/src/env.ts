import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

/// 读取后端本地 `.env` 文件。
///
/// 项目当前不额外引入 dotenv 依赖，这里只支持 `KEY=value` 和 `KEY="value"` 这类简单配置。
export function loadEnvFile(filePath = resolve(process.cwd(), '.env')): void {
  if (!existsSync(filePath)) {
    return;
  }

  const content = readFileSync(filePath, 'utf8');
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) {
      continue;
    }

    const separatorIndex = line.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    const value = unquote(line.slice(separatorIndex + 1).trim());
    if (process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

function unquote(value: string): string {
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return value.slice(1, -1);
  }
  return value;
}
