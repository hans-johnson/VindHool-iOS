// 把源单文件网页同步到 www/index.html（不做任何内容改动）
// 用法：
//   node scripts/sync-www.mjs                 # 默认源： ../delijn-realtime/index.html
//   node scripts/sync-www.mjs <源文件路径>     # 自定义源
import { copyFileSync, mkdirSync, statSync, readFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const src = resolve(root, process.argv[2] || '../delijn-realtime/index.html');
const destDir = resolve(root, 'www');
const dest = resolve(destDir, 'index.html');

mkdirSync(destDir, { recursive: true });

// 源文件不在（例如在 CI 上，只 checkout 了本仓库）时，沿用仓库里已提交的 www/index.html
let usedSrc = src;
let srcSize;
if (!existsSync(src)) {
  if (!existsSync(dest)) {
    console.error(`[sync-www] 源文件不存在，且 www/index.html 也没有：${src}`);
    process.exit(1);
  }
  usedSrc = dest;
  srcSize = statSync(dest).size;
  console.log('[sync-www] 未找到源文件，直接校验已提交的 www/index.html（CI 模式）');
} else {
  copyFileSync(src, dest);
  srcSize = statSync(src).size;
}

const destSize = statSync(dest).size;
if (srcSize !== destSize) {
  console.error(`[sync-www] 体积不一致：源 ${srcSize} / 目标 ${destSize}`);
  process.exit(1);
}

const text = readFileSync(dest, { encoding: 'utf8' });
const checks = {
  'viewport-fit=cover': text.includes('viewport-fit=cover'),
  'env(safe-area-inset': text.includes('safe-area-inset'),
};
console.log(`[sync-www] 源   ${usedSrc}`);
console.log(`[sync-www] 目标 ${dest}`);
console.log(`[sync-www] 体积 ${destSize} 字节 (${(destSize / 1048576).toFixed(2)} MB)`);
for (const [k, v] of Object.entries(checks)) console.log(`[sync-www] ${k}: ${v ? 'OK' : '缺失'}`);
if (!checks['viewport-fit=cover']) process.exit(2);
