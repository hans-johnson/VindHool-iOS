// 跨平台入口：npm run build:ipa
// macOS 上转交 build-ipa.sh（Xcode 编译）；Windows 上给明确提示，别让人白等。
import { spawnSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

if (process.platform !== 'darwin') {
  console.error('✗ iOS 的 .ipa 必须在 macOS 上编译（需要 Xcode 的 iphoneos SDK 与代码签名）。');
  console.error('  本机是 Windows：请走云端出包 .github/workflows/ios-ipa.yml');
  console.error('  （GitHub Actions 的 macOS runner 会直接产出可下载的 .ipa）');
  console.error('  有 Mac 时把整个工程拷过去，执行 bash scripts/build-ipa.sh');
  process.exit(1);
}

const sh = resolve(dirname(fileURLToPath(import.meta.url)), 'build-ipa.sh');
const r = spawnSync('bash', [sh, ...process.argv.slice(2)], { stdio: 'inherit' });
process.exit(r.status ?? 1);
