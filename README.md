# mole-app-native

**我们自己的桌面应用 · 原生版**——SwiftUI + AppKit,五个页面按 [mole.fit](https://mole.fit)
官方 Mac 版的界面逐页对齐。当前阶段:UI 全部可交互,真实扫描/清理逻辑下一步接进来。

> 学习/研究项目,与 Mole 官方无关联;文案与图形为本仓库原创示意。
> 数据来自 `Sources/MoleApp/Data.swift`(示意数据),不会执行任何真实清理。

## 运行

```bash
swift run        # 直接启动(需要 macOS 14+ 与 Xcode)
```

也可以用 Xcode 直接打开 `Package.swift`,或后续切换到 .xcodeproj 打包签名。

## 现在有什么

五个标签(清理 / 软件 / 优化 / 分析 / 状态),原生控件、全部可交互:

| 标签 | 交互 |
| --- | --- |
| 清理 | **已接真实数据**:扫描固定白名单 5 类(用户缓存/用户日志/Xcode DerivedData/设备支持/npm 缓存,跳过 `com.apple.*` 与 DiagnosticReports);真实体积与子项预览;勾选 → 确认 → **移到废纸篓**(可恢复),落闸前逐条重校验路径归属,符号链接一律跳过 |
| 软件 | **已接真实数据**:扫描 `/Applications` 与 `~/Applications`,真实图标(`NSWorkspace`)、版本与体积(四并发测量);展开显示真实关联残留,可「在访达中显示」;**更新**:Sparkle 应用(appcast)与 Homebrew(`brew outdated`)真实检查,Sparkle 走「打开更新」、Homebrew 走 `brew upgrade`;**启动项**:真实 LaunchAgents,用户级可持久启停,系统级只读 |
| 优化 | **已接真实执行**:Quick Look 缩略图重建、DNS 缓存刷新(弹系统授权,取消则跳过)、Spotlight 索引检查(只读)、磁盘校验(只读);逐项执行,结果/失败/跳过都写在行内 |
| 分析 | **已接真实数据**:从主目录开始逐层下钻真实文件/目录,四并发逐项测体积;点目录进入、点文件在访达中显示、右键菜单定位、面包屑返回;真实磁盘用量图例;跳过符号链接 |
| 状态 | **已接真实指标**:CPU 真实采样与滚动曲线、内存/交换空间、磁盘根卷、网络上下行速率、负载、电池、**GPU 利用率(IOAccelerator)**、**CPU 温度(SMC)**;进程表读 `ps` 的真实内存 TOP 8;风扇随机型,无 SMC 键的机器如实标注 |

窗口细节照官方:隐藏标题栏、交通灯浮在界面上、内容区域可直接拖动窗口,
每个标签有自己的窗口底色(清理藏蓝、软件暗棕、优化近黑、分析巧克力、状态橄榄)。

## 目录

```
Package.swift              # SwiftPM 工程(macOS 14+)
scripts/package_app.sh     # 本地/CI 打包 .app 与 zip(ad-hoc 签名)
Sources/MoleApp/
  MoleApp.swift            # App 入口、窗口配置(隐藏标题栏/拖动)
  ContentView.swift        # 顶部胶囊标签 + 页面切换 + 新版本提示
  Theme.swift              # 颜色与字体令牌
  Components.swift         # 复选框、能量条、火花线、按钮…
  CommandRunner.swift      # 带超时的进程执行器(brew / launchctl / ps…)
  AppVersion.swift         # 当前版本(打包读 Info.plist,开发运行回落常量)
  SelfUpdate.swift         # 基于 GitHub Releases 的自我更新检查
  SystemMetrics.swift      # 真实系统指标(CPU/内存/磁盘/网络/负载/进程/SMC)
  AppsScan.swift           # /Applications 扫描、真实图标/体积/关联残留
  LoginItems.swift         # 真实 LaunchAgents 读取与持久启停
  UpdateChecker.swift      # Sparkle appcast + Homebrew outdated
  CleanScan.swift          # 清理白名单扫描 + 废纸篓闭环
  AnalyzeScan.swift        # 真实目录树逐层扫描
  Pages/
    CleanPage.swift        # 清理:扫描/结果/清单/完成 四态
    AppsPage.swift         # 软件:卸载 / 更新 / 启动项
    OptimizePage.swift     # 优化:真实任务运行器 + 月球
    AnalyzePage.swift      # 分析:树形下钻 + 方块图
    StatusPage.swift       # 状态:指标卡 + 进程表
```

## 发布与更新

- **自动构建**:推送 `main` 或提 PR,GitHub Actions 会构建 .app 并上传构建产物(`Build` workflow)
- **发版**:`git tag v0.1.0 && git push origin v0.1.0` → `Release` workflow 自动打包 zip 并创建
  [GitHub Release](https://github.com/csic21/mole-app-native/releases)
- **下载安装**:在 Releases 下载 `MoleApp-x.y.z.zip`,解压后把 `MoleApp.app` 拖进「应用程序」
- **首次打开**:应用为 ad-hoc 临时签名、未公证,双击可能被 Gatekeeper 拦截——请**右键 → 打开**,或执行
  `xattr -dr com.apple.quarantine /Applications/MoleApp.app`
- **App 内更新检查**:启动时读取 GitHub Releases 的 latest tag 与本机版本比较;有新版本时右上角出现
  「↑ 新版本 vX.Y.Z」按钮,点击前往下载页(只提示,不自动下载)

## 下一步

1. ✓ 软件页:真实 `/Applications` 扫描、真实图标/版本/体积、真实关联残留(已完成)
2. ✓ 状态页:真实 CPU/内存/磁盘/网络/负载/电池 + 真实进程表(已完成)
3. ✓ 清理页:真实扫描 5 类白名单 → 确认后移到废纸篓(已完成)
4. ✓ 分析页:真实目录树扫描(已完成)
5. ✓ 优化页:真实执行 Quick Look 重建 / DNS 刷新 / Spotlight 检查 / 磁盘校验(已完成)
6. ✓ 启动项:真实 LaunchAgents 读取 + 用户级持久启停(已完成)
7. ✓ 更新检查:Sparkle(appcast)与 Homebrew(`brew outdated`)真实来源(已完成)
8. ✓ GPU 利用率(IOAccelerator)与 CPU 温度(SMC flt 键)(已完成;风扇随机型,无 SMC 键的机型如实标注不可读)

## 许可证

代码以 MIT 协议开源;「Mole」名称与 mole.fit 的界面设计归其所有者,本项目仅作学习用途。
