#!/usr/bin/env bash
# 把 Capacitor iOS 工程打成 .ipa —— 必须在 macOS 上运行（需要 Xcode + CocoaPods）
#
#   bash scripts/build-ipa.sh                       # 未签名 IPA（用 Sideloadly / AltStore 重签安装）
#   bash scripts/build-ipa.sh --team ABCDE12345     # 自动签名 + 导出 development IPA
#   bash scripts/build-ipa.sh --team ABCDE12345 --method ad-hoc
#
# 没有 Mac：用 .github/workflows/ios-ipa.yml（GitHub Actions 的 macOS runner）出包。
# 注意：Apple 不允许「未签名 IPA」直接装进普通 iPhone；未签名包必须用免费 Apple ID
#       经 Sideloadly / AltStore / 爱思助手重签，或按上面的 --team 走签名导出。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TEAM=""
METHOD="development"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --team)   TEAM="${2:-}"; shift 2 ;;
    --method) METHOD="${2:-development}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "未知参数：$1（试试 --help）" >&2; exit 2 ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "✗ 只能在 macOS 上运行：编译 iOS 原生壳需要 Xcode 的 iphoneos SDK 与代码签名。" >&2
  echo "  Windows 上请改用 .github/workflows/ios-ipa.yml（GitHub Actions 的 macOS runner）。" >&2
  exit 1
fi
for cmd in xcodebuild pod node npx zip unzip; do
  command -v "$cmd" >/dev/null || { echo "✗ 缺少 $cmd，请先安装（Xcode / CocoaPods / Node 22）" >&2; exit 1; }
done

# 1) 依赖与网页资源
if [[ ! -d node_modules/@capacitor/ios ]]; then
  echo "→ npm ci"; npm ci
fi
echo "→ 同步网页资源"
node scripts/sync-www.mjs            # 源 ../delijn-realtime/index.html 不在时自动用仓库内 www/index.html
# zip / CI checkout 里 public 与 cordova 兼容层可能被 .gitignore 忽略，先补空目录
mkdir -p ios/App/App/public ios/capacitor-cordova-ios-plugins/sources ios/capacitor-cordova-ios-plugins/resources
npx cap copy ios
cmp www/index.html ios/App/App/public/index.html

# 2) CocoaPods（Capacitor.framework）
echo "→ pod install"
( cd ios/App && pod install --no-repo-update )

# 3) archive
OUT="$ROOT/ios/App/output"
ARCHIVE="$ROOT/ios/App/build/App.xcarchive"
rm -rf "$ARCHIVE" "$OUT"
mkdir -p "$OUT"
echo "→ xcodebuild archive"
(
  cd ios/App
  if [[ -n "$TEAM" ]]; then
    xcodebuild -workspace App.xcworkspace -scheme App -configuration Release \
      -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
      DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
      clean archive
  else
    xcodebuild -workspace App.xcworkspace -scheme App -configuration Release \
      -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
      CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
      clean archive
  fi
)

APP="$ARCHIVE/Products/Applications/App.app"
[[ -d "$APP" ]] || { echo "✗ archive 里没有 App.app：$APP" >&2; exit 1; }

# 4) 导出 ipa
if [[ -n "$TEAM" ]]; then
  echo "→ exportArchive (method=$METHOD, team=$TEAM)"
  cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>${METHOD}</string>
  <key>teamID</key><string>${TEAM}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>stripSwiftSymbols</key><true/>
  <key>compileBitcode</key><false/>
</dict>
</plist>
PLIST
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportPath "$OUT/export" -exportOptionsPlist "$OUT/ExportOptions.plist"
  BUILT="$(find "$OUT/export" -maxdepth 1 -name '*.ipa' -print -quit)"
  [[ -n "$BUILT" ]] || { echo "✗ exportArchive 没有产出 .ipa" >&2; exit 1; }
  cp "$BUILT" "$OUT/VindHool-${METHOD}.ipa"
  IPA="$OUT/VindHool-${METHOD}.ipa"
else
  echo "→ 打未签名 IPA"
  mkdir -p "$OUT/Payload"
  cp -R "$APP" "$OUT/Payload/"
  IPA="$OUT/VindHool-unsigned.ipa"
  ( cd "$OUT" && zip -qry "$(basename "$IPA")" Payload )
fi

# 5) 校验：可执行壳 + 网页资源确实进包
unzip -l "$IPA" | grep -q 'Payload/App.app/Info.plist' || { echo "✗ 包内缺少 Info.plist" >&2; exit 1; }
WEB=$(unzip -p "$IPA" Payload/App.app/public/index.html | wc -c | tr -d ' ')
[[ "$WEB" -ge 1048576 ]] || { echo "✗ 包内网页资源异常（${WEB} 字节）" >&2; exit 1; }

echo ""
echo "✓ IPA: $IPA"
ls -lh "$IPA"
shasum -a 256 "$IPA" 2>/dev/null || true
echo "  包内网页 ${WEB} 字节"
if [[ -z "$TEAM" ]]; then
  echo "  这是未签名包：用 Sideloadly / AltStore / 爱思助手 + 免费 Apple ID 重签后装到 iPhone。"
  echo "  有付费开发者账号时：bash scripts/build-ipa.sh --team <TEAMID>"
else
  echo "  已按 $METHOD 签名导出，可用 Xcode → Devices / Apple Configurator / 爱思助手安装。"
fi
