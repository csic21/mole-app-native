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
| 清理 | 扫描进度 → 共 154.19GB → 查看结果(分类勾选、系统数据可展开)→ 立即清理 → 已释放 |
| 软件 | 卸载/更新/启动项三子页;行可勾选、点开展开清除明细;移除后列表即时更新 |
| 优化 | 点「优化 Mac」逐项执行,完成/跳过带原因,底部汇总实时变化 |
| 分析 | 方块图逐层下钻,侧栏与面包屑联动,可逐层返回 |
| 状态 | 指标每 1.5 秒跳动 + 进程表(原生定时器) |

窗口细节照官方:隐藏标题栏、交通灯浮在界面上、内容区域可直接拖动窗口,
每个标签有自己的窗口底色(清理藏蓝、软件暗棕、优化近黑、分析巧克力、状态橄榄)。

## 目录

```
Package.swift              # SwiftPM 工程(macOS 14+)
Sources/MoleApp/
  MoleApp.swift            # App 入口、窗口配置(隐藏标题栏/拖动)
  ContentView.swift        # 顶部胶囊标签 + 页面切换
  Theme.swift              # 颜色与字体令牌
  Data.swift               # 示意数据(未来接 FileManager / ProcessInfo 的落点)
  Components.swift         # 复选框、能量条、火花线、按钮…
  Pages/
    CleanPage.swift        # 清理:扫描/结果/清单/完成 四态
    AppsPage.swift         # 软件:卸载 / 更新 / 启动项
    OptimizePage.swift     # 优化:任务运行器 + 月球
    AnalyzePage.swift      # 分析:树形下钻 + 方块图
    StatusPage.swift       # 状态:指标卡 + 进程表
```

## 下一步

1. 清理页接真实扫描:`FileManager` 遍历缓存/日志候选,先预览后删(进废纸篓);
2. 软件页读 `/Applications`,用 `NSWorkspace` 取真实图标与大小;
3. 状态页接 `ProcessInfo` / `host_statistics` 真实指标;
4. 分析页接真实目录树扫描。

## 许可证

代码以 MIT 协议开源;「Mole」名称与 mole.fit 的界面设计归其所有者,本项目仅作学习用途。
