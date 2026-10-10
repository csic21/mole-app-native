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
| 软件 | **已接真实数据**:扫描 `/Applications` 与 `~/Applications`,真实图标(`NSWorkspace`)、版本与体积(四并发测量);展开显示真实关联残留,可「在访达中显示」;更新与启动项仍为示意 |
| 优化 | 点「优化 Mac」逐项执行,完成/跳过带原因,底部汇总实时变化 |
| 分析 | 方块图逐层下钻,侧栏与面包屑联动,可逐层返回 |
| 状态 | **已接真实指标**:CPU 真实采样与滚动曲线、内存/交换空间、磁盘根卷、网络上下行速率、负载、电池;进程表读 `ps` 的真实内存 TOP 8;GPU 与 SMC(温度/风扇)已标注为下一步 |

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

1. ✓ 软件页:真实 `/Applications` 扫描、真实图标/版本/体积、真实关联残留(已完成)
2. ✓ 状态页:真实 CPU/内存/磁盘/网络/负载/电池 + 真实进程表(已完成)
3. ✓ 清理页:真实扫描 5 类白名单 → 确认后移到废纸篓(已完成)
4. 分析页:真实目录树扫描
5. 更新与启动项接入真实来源(Sparkle / ServiceManagement)
6. GPU 利用率、SMC 温度与风扇(需要 IOKit 更深接入)

## 许可证

代码以 MIT 协议开源;「Mole」名称与 mole.fit 的界面设计归其所有者,本项目仅作学习用途。
