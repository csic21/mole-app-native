# 栖理 Qili

一个独立开发的原生 Mac 空间与维护工作台。采用侧栏导航、分类清单和任务面板，
把文件占用、应用管理与日常维护放在同一处。支持 macOS 14 及以上。

## 当前功能

| 工具 | 已实现 | 边界 |
| --- | --- | --- |
| 空间整理 | 用户缓存、日志、Xcode DerivedData、设备支持与 npm 缓存扫描；分类与逐项勾选、路径明细、固定确认栏、停止扫描、确认后移到废纸篓 | 路径白名单与符号链接检查；不清空废纸篓 |
| 应用管理 | 本机应用、图标、版本与大小；搜索、大小排序、按需加载关联文件；Sparkle / Homebrew 更新检查；用户级启动项启停 | 暂不执行应用卸载；系统启动项只读 |
| 系统维护 | Quick Look 重建、DNS 刷新、Spotlight 索引检查、磁盘校验；按需选择或单独运行、停止后续任务、展开执行记录 | 需要权限时由系统授权；索引与磁盘检查只读 |
| 文件地图 | 文件夹选择、逐层测量、占比分布、卡片/列表、搜索、短期返回缓存；在访达中显示 | 此页不执行删除 |
| 运行状态 | CPU / GPU / 内存 / 磁盘 / 网络 / 负载 / 电池及内存占用较高的进程 | 仅前台采样，硬件读取在后台线程；温度、风扇和电池指标随机型可用，无法读取时明确标注 |

扫描与维护通过本机系统接口和命令完成。自我更新检查会请求本仓库的 GitHub Releases；
应用更新检查还会访问相应更新来源。没有把本机文件内容上传到服务端的功能。

## 开发与打包

```bash
swift run
bash scripts/package_app.sh 0.4.2              # dist/Qili.app 与 dist/Qili-0.4.2.zip
bash scripts/package_app.sh 0.4.2 .build/qili-preview
```

也可用 Xcode 打开 `Package.swift`。内部 SwiftPM 目标仍叫 `MoleApp`，仓库 URL 和
bundle identifier 保留以兼容已有构建与更新检查；产品显示名和发行包使用栖理 / Qili。

下载包解压后，将 `Qili.app` 拖入应用程序。当前使用 ad-hoc 签名，尚未完成公证。

## 验证与扫描基准

```bash
swift test
swiftc -O Sources/MoleApp/FileSizer.swift scripts/scan_benchmark.swift -o /tmp/qili-scan-benchmark
/tmp/qili-scan-benchmark                       # 自动生成并移除 1 万文件的临时测试集
/tmp/qili-scan-benchmark /path/to/directory    # 只读测量指定目录
```

扫描内核使用系统 FTS 物理遍历，不跟随符号链接、不改变工作目录，并逐项检查任务取消。
大小按文件数据分配块计算，权限失败显示不完整结果。资源叉/扩展属性可能造成与 Foundation
资源属性统计的差异；APFS 克隆、硬链接也不等于可独占释放的空间。移入废纸篓仍占用磁盘空间。

2026-10-11 本机暖缓存测试（100 目录、10,000 文件，5 次中位数）：Foundation 48 ms，
FTS 15 ms，约 3.3 倍，均统计到 40,960,000 字节。这是扫描内核的测试结果，
不是整机清理或冷缓存扫描的提速承诺。目录返回缓存最多保留 12 个目录、有效期两分钟，
手动重新测量始终绕过缓存。

回归覆盖普通文件、隐藏项、符号链接、稀疏文件、取消扫描、逐项选择、清理路径重校验、
目录返回缓存、命令大量双路输出/超时/取消及网络计数重置。测试不清理真实用户文件。

## 原生界面验证

设计说明、交互边界与人工检查清单见 [界面设计说明](docs/DESIGN_REFRESH.md)。

```bash
python3 scripts/check_design_contrast.py
bash scripts/capture_design_snapshots.sh      # 需 macOS 图形登录会话；输出到 .build/design-snapshots
```

截图测试使用实际 SwiftUI / AppKit 视图与隔离的示例状态，不启动正常应用，不扫描或移动本机文件。
普通 `swift test` 检查示例状态安全性；仅显式运行截图脚本时输出 PNG。

## 品牌素材

透明背景的 1024px 母版：`Assets/Branding/QiliLogo.png`。
鼹鼠图形由内置 image_gen 生成，未输入原版 Logo 作为参考；原始提示词保留在同目录。

```bash
bash scripts/generate_icons.sh
```

该脚本生成多尺寸 `AppIcon.icns`、SwiftPM 图片资源，以及网站 Logo 与 favicon。
打包脚本会把 SwiftPM 资源包复制进 `.app`，开发运行与发行包共用同一套素材。

## 网站

`site/` 是 React + Vite 的产品介绍页，采用独立设计的工作台示意和五项功能说明。
网页数据明确标为示例，不在浏览器中执行本机扫描或清理。

```bash
cd site
pnpm install --frozen-lockfile
pnpm dev
PAGES_BASE=/mole-app-native/ pnpm build
```

Pages 工作流仍使用现有仓库路径。下载与源码链接均指向本项目。

## 发布

推送 main 或提交 PR 会构建应用；推送 `v*` 标签会生成 `Qili-<version>.zip` 并发布 GitHub Release。
版本常量位于 `Sources/MoleApp/AppVersion.swift`，发版时应与标签一致。
发布精确已验证提交、请求格式与安装包核验步骤见 [发布说明](docs/RELEASING.md)。

## 来源与许可

本项目代码使用 [MIT 许可证](LICENSE)。历史版本曾参考 Mole 的公开界面，
当前已调整为独立品牌与工作台设计；不表示与 Mole 或 Tw93 存在授权、关联或认可关系。
CLI 的 GPL 许可不自动授予品牌或专有 Mac 产品界面的使用权。

代码检索范围、素材来源、第三方依赖与后续引入 GPL 代码的要求见
[来源与许可说明](docs/PROVENANCE.md)。此说明不替代完整的代码来源审计或商标检索。
