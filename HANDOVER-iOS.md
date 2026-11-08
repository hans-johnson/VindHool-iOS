# 接手文档：用 GitHub Actions 出 iPhone 的 .ipa（A 路）

> 本文档自包含，接手者**不需要**看之前的对话。状态核对时间：2026-11-09 02:18 GMT+8。
> 项目：De Lijn 实时公交地图（比利时），Capacitor 壳 + 单文件网页。

---

## 0. 一句话现状

本机是 **Windows，不能直接编译 `.ipa`**（iOS 原生壳要 macOS 的 Xcode + Apple 代码签名）。
已选定 **A 路**：把 `delijn-realtime-android` 这个壳仓库 push 到 GitHub，由
`.github/workflows/ios-ipa.yml` 在 **macOS runner** 上编译并产出 `VindHool-unsigned.ipa`。

**A 路已经跑通，`VindHool-unsigned.ipa` 已产出**（结果见 §0.1）。
下面 §3 的步骤现在主要用于「复现」或「以后改了网页重新出包」；
日常只需要按 §6 更新 `www/index.html` 并 push，CI 会自动重新出 IPA。

---

## 0.1 本次实际执行结果（2026-11-09 02:43 GMT+8）

| 项 | 值 |
|---|---|
| GitHub 仓库 | **https://github.com/hans-johnson/VindHool-iOS**（公开，默认分支 `main`） |
| 账号 / 授权 | `hans-johnson`；winget 装 GitHub CLI 2.103.3 → 设备码登录，token scopes `repo, workflow`。凭据存在系统 keyring，**未写入 `.git/config`**（push 用一次性 HTTP header） |
| 首个 commit | `93e3d5f` — 85 个文件，`iOS shell: Capacitor 7 + unsigned IPA workflow` |
| CI run | `iOS IPA (unsigned)` **42511083463**，push 自动触发，macos-15，**2 分 14 秒全绿**（7 步：checkout → node → Xcode → npm ci → 网页校验 → cap copy → pod install → archive → 打包 → 包内校验 → 上传） |
| 产物 | artifact `VindHool-unsigned-93e3d5f…zip` → `VindHool-unsigned.ipa`，**3,754,947 字节（3.58 MiB）**；本机已存 `dist/VindHool-unsigned.ipa` |
| 包内核验 | `Payload/App.app/public/index.html` = **12,279,294 字节 / md5 `e940bcc3…`**，与 `www/index.html` 逐字节一致；`CFBundleIdentifier=com.phant.delijnrt`、`MinimumOSVersion=14.0`、`arm64`、**未签名**（无 `_CodeSignature`） |
| artifact 到期 | 保留 **14 天**（约 2026-11-22），地址：仓库 → Actions → 该 run → Artifacts |

安装方式见 §3.7：未签名 IPA 必须 Sideloadly / AltStore / 爱思助手配合 Apple ID 重签。

⚠️ 同一仓库还有一条 `Android Debug APK` 工作流。首次 push 它因
`android-actions/setup-android@v3` 默认安装已下架的 `tools` 包而失败
（`Warning: Failed to find package 'tools'` → sdkmanager exit 1），**与 iOS 无关**；
已改为 `with: packages: platform-tools` 并推送修复。

⚠️ 新增了 `.gitattributes`：`www/index.html` 标 `-text`、`.sh` 等标 `eol=lf`。
首次提交时实测 Windows 的 `core.autocrlf` 会把网页从 12,279,294 转成 12,271,086 字节
（少 8,208 个 CR），加了它之后仓库 blob 与源文件字节、md5 才完全一致。
**以后不要删这个文件**，否则 CI 里 `cmp` 与包内字节数校验会失准。

---

## 1. 两个目录谁是什么

| 路径 | 作用 | 是否进 GitHub 仓库 |
|---|---|---|
| `C:\Users\PHANT\Documents\Trae-CN\delijn-realtime\` | **网页源码与数据**：`web/app.html`、`data/`、`tools/build-web.js`，产出 `index.html`（单文件 11.7 MB） | 否（在仓库外） |
| `C:\Users\PHANT\Documents\Trae-CN\delijn-realtime-android\` | **Capacitor 壳工程**：`www/`、`android/`、`ios/`、`scripts/`、`.github/workflows/` | **是，这个目录就是仓库根** |

构建链：`delijn-realtime/index.html` → 复制到壳的 `www/index.html`
→ CI 里 `cap copy ios` 复制到 `ios/App/App/public/index.html` → Xcode 打进 `App.app` → 压缩成 IPA。

---

## 2. 当前状态（已核对，别重新猜）

- 应用：`appId = com.phant.delijnrt`，`appName = VindHool`，Capacitor **7.6.10**，iOS deployment target **14.0**。
- 网页：`index.html` / `www/index.html` / `ios/App/App/public/index.html` /
  `android/app/src/main/assets/public/index.html` / APK 内资源 **五处 md5 全一致 `e940bcc3…`**，
  文件 **12,279,294 字节**（约 11.71 MiB）。
- iPhone 适配已完成：顶栏「‹」返回按钮（iOS 无系统返回键，Android/浏览器隐藏）、
  `Info.plist` 改 `arm64` + 加密声明、补齐 `App.xcworkspace/contents.xcworkspacedata`、
  图标/启动图/scheme/Podfile 齐全。
- 实时接口对 `Origin: capacitor://localhost` 返回 `Access-Control-Allow-Origin: *`，iOS 壳内能取到数据。
- `scripts/build-ipa.sh`（Mac 本地出包，备选 B 路）已通过 `bash -n`；`build-ipa.mjs` 通过 `node --check`。
- `VindHool-iOS-build.zip`（5.86 MB / 36 文件）是给 Mac 用的离线工程包，**是可重建的生成物**。
- APK 已按同一份网页重打成功（BUILD SUCCESSFUL），路径
  `android/app/build/outputs/apk/debug/app-debug.apk`。

### 本机 Git 环境（重要）

| 项 | 状态 |
|---|---|
| Git | 2.55.0.windows.3，可用 |
| `.git` | 已有 **1 个 commit `93e3d5f`**，`origin` = `https://github.com/hans-johnson/VindHool-iOS.git` |
| 全局 `user.name` / `user.email` | 仍**未配置**（不污染全局）；已设仓库级 `hans-johnson` / `3396363+hans-johnson@users.noreply.github.com`（GitHub noreply，避免公开真实邮箱） |
| `gh` CLI | **已装 2.103.3**（winget），已登录 `hans-johnson`，scopes `repo, workflow` |
| 当前分支 | `main`，已追踪 `origin/main`（workflow 只监听 `main`） |
| 忽略规则 | `.gitignore` 追加 `VindHool-iOS-build.zip` / `*.bak-*` / `dist/`；`.gitattributes` 管换行 |

> 本机可执行文件真实路径：`C:\Users\PHANT\AppData\Local\Microsoft\WinGet\Packages\GitHub.cli_Microsoft.Winget.Source_8wekyb3d8bbwe\bin\gh.exe`。
> WinGet Links 目录里的 `gh.exe` 是 0 字节别名，在 Git Bash 里调用会静默无输出，别用它。

### 敏感信息核查（公开仓库前必看）

扫描了 `www/index.html`、`capacitor.config.json`、`scripts/`、`.github/`、`package.json`：

- **没有硬编码密钥**：`gmKey = ''`（Google Maps key 运行时输入，只存本机 localStorage）；
  未发现 `Ocp-Apim-Subscription-Key`、`password=` 赋值、私钥块。
  命中的 `password` 只是 `<input type="password">` 的字段名。
- 但仓库里包含整份网页与站点/线路/车队数据，**公开仓库任何人都能看到内容**。
  ⚠️ 以后**绝不要**把 API key、token 写进 `index.html` 或任何提交文件；真放了就等于公开。

---

## 3. 复现 / 换仓库重来（PowerShell，逐行执行）

> **本节步骤本次已全部执行完毕**（结果见 §0.1）。只有换新仓库、迁到别的账号，
> 或删掉 `.git` 重来时才需要重做；日常更新网页直接走 §6。
> 本机已配好 GitHub 凭据，`git push` 无需再输密码（见 §3.5 末尾）。

工作目录固定为壳工程根：

```powershell
cd C:\Users\PHANT\Documents\Trae-CN\delijn-realtime-android
git status --short
```

### 3.1 在 GitHub 网页建一个空仓库

浏览器打开 `https://github.com/new` → 填仓库名 → **不要勾选** README / .gitignore / License
→ 创建。复制它给出的 HTTPS 地址 `https://github.com/<账号>/<仓库>.git`。

> 建议用**公开仓库**：GitHub 对公开仓库的 macOS runner 免费；私有仓库的 macOS 分钟数按 10 倍计，
> 一次 45 分钟的 job 会扣很多免费额度。

### 3.2 配置仓库级提交身份（本机全局未配置，只改本仓库）

```powershell
git config user.name "你的名字"
git config user.email "你的邮箱"
```

如果按 §2 的说明删过 `.git`，这里补一句 `git init`。

### 3.3 建议先排除两个可重建/无用的文件

`VindHool-iOS-build.zip`（6 MB 生成物）和 `MainActivity.java.bak-2026-11-08`（旧备份）
默认会被 `git add .` 带上。执行下面两行把它们排除：

```powershell
Add-Content .gitignore "`nVindHool-iOS-build.zip`n*.bak-*"
```

（只追加 ASCII，别加 `-Encoding utf8` —— Windows PowerShell 5.1 会在追加时写 BOM，
可能把 `.gitignore` 里已有的中文注释弄坏。）

（不执行也行，只是仓库里会多 6 MB。`www/index.html` **绝不能**加进 `.gitignore` ——
CI 里没有仓库外的源文件，它是网页的唯一来源。）

### 3.4 暂存、检查、提交

```powershell
git add .
git status --short
git commit -m "iOS shell: Capacitor 7 + unsigned IPA workflow"
```

`git status --short` 里应当看到：`.github/workflows/`、`.gitignore`、`README-build.md`、
`HANDOVER-iOS.md`、`www/index.html`、`ios/`、`package*.json`、`scripts/`、`capacitor.config.json`。
**不应出现** `node_modules/`、`android/app/build/`、`android/.gradle/`、`*.log`（`.gitignore` 已挡住）。

### 3.5 关联远程并 push

```powershell
git remote add origin https://github.com/<账号>/<仓库>.git
git branch -M main
git push -u origin main
```

本机已把 GitHub 凭据接到 gh CLI：**全局 git config 里对 `https://github.com` 指定了
`gh.exe auth git-credential`**，之后 `git push` 直接可用，无需输密码、无需 PAT
（token 存在系统 keyring，不在 `.git/config` 里）。换机器时执行一次
`gh auth login --web --scopes "repo,workflow"` + `gh auth setup-git` 即可。
若 gh 别名在 Git Bash 下不生效，把 helper 里的 `gh.exe` 换成 §2 表格下方那个真实绝对路径。

### 3.6 触发构建并下载 IPA

1. 首次 push **通常会自动触发** `iOS IPA (unsigned)`（workflow 的 `paths` 包含
   `www/index.html` / `ios/**` / `package*.json` / workflow 本身）。
   若 Actions 里没动静：仓库 → **Actions** → 左侧 `iOS IPA (unsigned)` → **Run workflow** → 选 `main`。
2. **实测 2 分 14 秒**（macos-15：`npm ci` + `pod install` + Xcode archive + 打包），
   排队久时可能到 5–15 分钟。可用 `gh run watch <run-id> -R hans-johnson/VindHool-iOS --exit-status` 盯进度。
3. 跑完可用命令行直接取产物，不必点网页：
   ```powershell
   gh run download <run-id> -R hans-johnson/VindHool-iOS -D dist/dl
   ```
   或仓库 → Actions → 该 run → 底部 **Artifacts** → 下载 `VindHool-unsigned-<commit sha>.zip`
   → 解压得到 **`VindHool-unsigned.ipa`**（artifact 只保留 **14 天**，及时下载）。

### 3.7 装到 iPhone（未签名包必须重签）

- **Windows 最省事**：装 Sideloadly → 数据线连 iPhone → 拖入 IPA → 填 Apple ID（建议小号）
  → Start → 手机上「设置 → 通用 → VPN 与设备管理」信任该开发者。
- 或 AltServer（有 Windows 版）+ AltStore，把 IPA 用 AltStore 安装，会自动续签。
- **免费 Apple ID 签名 7 天过期**：AltStore 自动续签；Sideloadly 需每周重签一次。
- 想要长期稳定 / 分发给别人的包：走 §8 的 B 路，用付费开发者账号出已签名 IPA。

---

## 4. workflow 每一步在干什么 / 验收点

`.github/workflows/ios-ipa.yml`，`runs-on: macos-15`。

| 步骤 | 期望日志 |
|---|---|
| Set up Node / npm ci | Node 22，依赖装好（用 `package-lock.json`） |
| Verify committed www/index.html | `www/index.html size=12279294`（数值随数据更新会变）、`结构校验通过` |
| Capacitor copy (ios) | `Copying web assets from www to ios/App/App/public`、`iOS 网页资源与 www/index.html 完全一致` |
| CocoaPods install | `Pod installation complete!`，`Pods/Pods.xcodeproj` 存在 |
| Archive (no code signing) | `** ARCHIVE SUCCEEDED **`（`CODE_SIGNING_ALLOWED=NO`，不需要 Apple 账号） |
| Pack unsigned IPA | `Payload/App.app` 打进 `VindHool-unsigned.ipa` |
| Verify IPA contents | `包内网页 … 字节`，且与 `www/index.html` **字节数相等**；打印 sha256 |
| Upload IPA artifact | `VindHool-unsigned-<sha>` 可下载 |

包内关键路径：`Payload/App.app/Info.plist`、`Payload/App.app/public/index.html`。
（`public` 在 Xcode 工程里是 folder reference，网页会整体进 bundle。）

---

## 5. 交接验收清单

- [ ] GitHub 空仓库已建、`main` 分支上有文件
- [ ] `www/index.html` 确实在仓库里（约 12 MB，`node_modules/` 不在）
- [ ] Actions 的 `iOS IPA (unsigned)` 全绿、artifact 可下载
- [ ] 解压得到 `VindHool-unsigned.ipa`，能查到 `Payload/App.app/public/index.html`
- [ ] Sideloadly / AltStore 重签后，iPhone 上能打开 App、地图与实时车辆能加载
- [ ] iOS 顶栏「‹」返回按钮可用（点进线路/站点后能退回）
- [ ] 记住 artifact 14 天过期、免费签名 7 天过期

---

## 6. 以后改了网页，怎么重新出 IPA

```powershell
cd C:\Users\PHANT\Documents\Trae-CN\delijn-realtime
node tools/build-web.js                 # 源码 + 数据 → index.html

cd ..\delijn-realtime-android
npm run sync:ios                        # sync-www + cap copy ios（更新 www 与 iOS public）
npm run build:apk                       # 可选：让 Android 包保持同一份网页
git add www/index.html
git commit -m "更新实时数据 / 界面"
git push                                # 自动触发 iOS IPA 工作流
```

⚠️ `ios/App/App/public/` 与 `android/app/src/main/assets/public/` 都在 `.gitignore` 里，
**不要提交、也不用提交**：CI 会从 `www/index.html` 重新生成。只提交 `www/index.html` 就会触发出包。

---

## 7. 故障排查

| 现象 | 处理 |
|---|---|
| `git commit` 报 `Please tell me who you are` | 执行 §3.2 的 `git config user.name/email` |
| `git push` 认证失败 | 用浏览器授权 / PAT（勾 `repo`）/ GitHub Desktop，别用账号密码 |
| Actions 里看不到 workflow | 确认分支名是 `main`、文件在 `.github/workflows/`、仓库 Settings → Actions 已启用；workflow 必须在默认分支上才会显示 `Run workflow` |
| `npm ci` 失败 | `package.json` 与 `package-lock.json` 不一致；本机 `npm install` 后把 lock 一起提交 |
| `pod install` 失败 / 找不到 CocoaPods | runner 镜像差异：把 `runs-on: macos-15` 改成 `macos-14` 再跑 |
| `xcodebuild` 报需要 development team | 确认三参还在：`CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` |
| `** ARCHIVE FAILED **` 且提到 `public` | `www/index.html` 没提交或体积 <1 MB；看 Verify 那一步 |
| artifact 里只有 zip | 再解压一层，里面就是 `VindHool-unsigned.ipa` |
| IPA 装不上 / 提示未签名 | 正常：未签名包必须经 Sideloadly / AltStore 重签，不能直接安装 |
| Windows 上 `npm run build:ipa` 报错 | 预期行为：它会打印 A 路 / B 路指引并退出，不会产出 IPA |
| 排队很久 | 私有仓库 macOS 分钟数按 10 倍计；改公开仓库或等空闲时段 |

---

## 8. 已知限制 / 不要做的事

1. **不要在 Windows 上等本地出 IPA**：Apple 只允许 macOS + Xcode 编译与签名。
   `npm run build:ipa` 在 Windows 上只给指引。
2. **不要把密钥写进 `index.html`**（公开仓库 = 全世界可读）；运行时输入的 key 只在 localStorage。
3. **不要把 `www/index.html` 加进 `.gitignore`**：CI 里它是唯一的网页来源。
4. **不要提交 `node_modules/`、Android 构建产物、`.log`、离线 zip**：`.gitignore` 已挡住前三者，zip 见 §3.3。
5. 备用 **B 路（有 Mac）**：解压 `VindHool-iOS-build.zip` → `npm ci` →
   `bash scripts/build-ipa.sh` → `ios/App/output/VindHool-unsigned.ipa`；
   有付费账号时 `bash scripts/build-ipa.sh --team <TEAMID>` 出已签名包。
   详见 `README-build.md` §C2。

---

## 9. 关键文件索引

| 文件 | 用途 |
|---|---|
| `www/index.html` | **唯一网页产物**，CI 的输入，必须提交 |
| `.github/workflows/ios-ipa.yml` | A 路出包工作流（macOS runner → unsigned IPA → artifact） |
| `.github/workflows/android.yml` | 原有 Android Debug APK 工作流，别误改 |
| `capacitor.config.json` | appId / appName / webDir / iOS 开关 |
| `ios/App/App.xcodeproj/project.pbxproj` | Xcode 工程（`public` 为 folder reference） |
| `ios/App/App.xcworkspace/contents.xcworkspacedata` | workspace 引用（本轮补齐） |
| `ios/App/Podfile` | Capacitor + CapacitorCordova 两个本地 pod |
| `ios/App/App/Info.plist` | `arm64`、定位权限说明、加密声明 |
| `scripts/sync-www.mjs` | 把网页源码复制到 `www/`（源不在时用仓库内已有文件） |
| `scripts/build-ipa.sh` / `build-ipa.mjs` | B 路 Mac 出包 / 跨平台入口 |
| `package.json` | `sync:ios`、`build:ipa`、`build:apk` 等脚本 |
| `README-build.md` | 构建总说明（§C 是 iOS 章节） |
| `HANDOVER-iOS.md` | **本文档** |
| `VindHool-iOS-build.zip` | Mac 离线工程包（可重建，不必提交） |

---

**下一步**：接手者按 §3 走完就能拿到 IPA。若要把仓库初始化/提交也交给 AI 代做，
只需提供 GitHub 空仓库地址，并确认是否允许执行 `git config` / `git commit` / `git push`。
