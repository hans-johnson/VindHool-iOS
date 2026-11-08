# 构建 Debug APK（本机 / 云端两条路）

> 本机已具备完整工具链，**优先走方式 A**，不需要 GitHub。
> 当前状态：`android/app/build/outputs/apk/debug/app-debug.apk` 已构建（11,113,971 B，debug 签名，
> 含 2026-11-08 的修复：线路 12（Antwerpen）偏离轨迹误报根治（`12|AN` 改按站坐标生成折线）、
> 线路 44（Leuven→Linden Kerk）补回 12 个缺失站名并裁掉越过终点的支路、站点卡删「本站附近车辆」块、
> 搜索框橙色框选边框移除、城市标注中文（鲁汶等）、空态「暂无车辆」）；
> 包内 `assets/public/index.html` 与 `delijn-realtime/index.html` md5 一致（`dae14d847…`）。
> 最近一次 `assembleDebug` 于 2026-11-08 复跑成功（BUILD SUCCESSFUL）。

## A. 本机构建（推荐）

环境：JDK 21、Android SDK 35 + build-tools 35（`android/local.properties` 已指向
`C:\Users\PHANT\android-sdk`）、仓库自带的 Gradle Wrapper 8.11.1（不用另装 Gradle）。

```powershell
cd C:\Users\PHANT\Documents\Trae-CN\delijn-realtime
node tools/build-web.js                 # 先把网页源码 + 数据构建成 index.html

cd ..\delijn-realtime-android
npm run build:apk                       # sync-www + cap sync + assembleDebug
```

等价分步：`node scripts/sync-www.mjs` → `npx cap sync android` →
`cd android; .\gradlew.bat assembleDebug`。

产物：`android/app/build/outputs/apk/debug/app-debug.apk`。
若网页没变化，Gradle 会显示 `UP-TO-DATE`、沿用已有 APK —— 这是正常的，内容仍与最新页面一致。

装到手机（USB 调试已开）：

```powershell
& "C:\Users\PHANT\android-sdk\platform-tools\adb.exe" install -r "android\app\build\outputs\apk\debug\app-debug.apk"
```

> `package.json` 的 `install:apk` 指向 `scripts/install-apk.mjs`，该脚本目前不存在，
> 请直接用上面的 adb 命令。另外构建日志里的 `hs_err_pid*.log` 是早前物理内存不足留下的崩溃记录，
> 与当前构建无关。

## B. 云端构建（GitHub Actions）

### 1. 用户要做的三步（在 `delijn-realtime-android` 目录下用 PowerShell 执行）

```powershell
git init
git add .
git commit -m "Android WebView shell for De Lijn 实时"
git remote add origin https://github.com/<你的账号>/<仓库名>.git
git branch -M main
git push -u origin main
```

（先在 GitHub 网页上新建一个空仓库，不要勾选 README/.gitignore；`<你的账号>/<仓库名>` 换成实际地址。）

### 2. 下载 APK

GitHub 网页 → 该仓库的 **Actions** 标签 → 点最近一次 `Android Debug APK` 的 run →
页面底部 **Artifacts** → 下载 `app-debug-<commit sha>.zip` → 解压得到 `app-debug.apk`。

### 3. 装到手机

USB 连接（已开 USB 调试）：

```powershell
& "C:\Users\PHANT\android-sdk\platform-tools\adb.exe" install -r "<解压后的 app-debug.apk 路径>"
```

或者把 APK 传到手机，用文件管理器点安装（首次需允许「未知来源」安装）。

### 返回键行为（2026-11-08 起）

屏幕上的「← 返回」按钮已全部取消，统一用 Android 系统返回键。
系统返回不再先折叠底部列表抽屉，而是直接回上一级视图（详情 → 列表 → 清空结果 → 退出）。
`MainActivity.onBackPressed()` 仍把事件交给页面的 `window.dlBack()`，页面返回 `false` 时才结束 Activity。
**iOS 例外**：iPhone 没有系统返回键，网页在 `window.Capacitor.getPlatform() === 'ios'` 时
自动显示顶栏「‹」按钮（调用同一个 `goBack()`）；Android 与浏览器里该按钮始终隐藏。

## C. 构建 iPhone 的 .ipa

> 完整交接清单（含仓库初始化、push、下载、重签安装、故障排查）见 **[HANDOVER-iOS.md](HANDOVER-iOS.md)**。

> **Windows 本机不能直接产出 .ipa**：iOS 原生壳要 Xcode 的 iphoneos SDK、Swift 编译器和
> Apple 代码签名，这三样只有 macOS 有。本机已经把 iOS 工程与出包链全部备好，二选一即可拿到 .ipa。

### C1. 云端出包（不用 Mac，推荐）

`.github/workflows/ios-ipa.yml` 跑在 GitHub Actions 的 **macos-15** runner 上（自带 Xcode + CocoaPods）：

1. 按上面「B. 云端构建」的第 1 步把仓库 push 到 GitHub（`www/index.html` 必须提交，
   `.gitignore` 已放行；`ios/App/App/public/` 被忽略，CI 里由 `cap copy ios` 重新生成）。
2. GitHub → **Actions** → `iOS IPA (unsigned)` → **Run workflow**（或 push 到 main 触发）。
3. 跑完在 run 页面底部 **Artifacts** 下载 `VindHool-unsigned-<sha>.zip`，
   解压得到 `VindHool-unsigned.ipa`。
4. 这是**未签名**包：用 Sideloadly / AltStore / 爱思助手 + 免费 Apple ID 重签后装到 iPhone
   （免费签名 7 天有效，AltStore 会自动续签）。CI 会校验包内 `App.app/public/index.html`
   与仓库里的 `www/index.html` 字节数一致。

### C2. Mac 本机出包

把整个工程（或 `VindHool-iOS-build.zip`）拷到 Mac，装好 Xcode（含命令行工具）、
CocoaPods、Node 22，然后：

```bash
cd delijn-realtime-android
npm ci                         # 如果 zip 里没带 node_modules
bash scripts/build-ipa.sh       # → ios/App/output/VindHool-unsigned.ipa
```

有付费开发者账号时，先在 Xcode → Settings → Accounts 登录，再：

```bash
bash scripts/build-ipa.sh --team <TEAMID>                # development 签名
bash scripts/build-ipa.sh --team <TEAMID> --method ad-hoc # 指定设备列表
```

TEAMID 在 developer.apple.com → Membership 里查。产物用 Apple Configurator /
Xcode Devices and Simulators / 爱思助手装入手机。`npm run build:ipa` 是同一个入口
（Windows 上会直接打印上面这两条路，不会白跑）。

### iOS 工程与 Android 的差异

| 项 | iOS |
|---|---|
| 网页资源 | `ios/App/App/public/index.html`，由 `npm run sync:ios`（= `sync-www` + `cap copy ios`）从 `www/` 复制 |
| 返回 | 顶栏「‹」按钮（iOS 无系统返回键），调 `window.dlBack()` |
| 设备能力 | `Info.plist` 用 `arm64`（模板默认 `armv7` 已过时） |
| 加密声明 | `ITSAppUsesNonExemptEncryption=false`，导出时不再被追问 |
| workspace | `ios/App/App.xcworkspace/contents.xcworkspacedata` 已补齐（原模板只有 IDEWorkspaceChecks.plist，`pod install` 也会生成） |
| 签名 | 默认 `CODE_SIGNING_ALLOWED=NO` 出未签名包；`--team` 走自动签名 + `exportArchive` |

改完网页后：`node tools/build-web.js` → `npm run sync:ios`（+ 想同步 APK 就再 `npm run build:apk`），
两边共用同一个 `index.html`，md5 必须一致。
